// Product Master Search Component - Module 7
/**
 * @description LWC component for searching and selecting products from the ERP-synced
 *              Product Master. Per BRD Module 7, users can only search & select products
 *              from the synced list. No create/edit/delete allowed in Salesforce.
 *              Used in Opportunities, Quotes, and Orders.
 */
import { LightningElement, api, track, wire } from 'lwc';
import searchProducts from '@salesforce/apex/ProductSearchController.searchProducts';
import getProductDetails from '@salesforce/apex/ProductSearchController.getProductDetails';
import getProductCategories from '@salesforce/apex/ProductSearchController.getProductCategories';
import getProductFamilies from '@salesforce/apex/ProductSearchController.getProductFamilies';

export default class ProductSearch extends LightningElement {
    @api recordId;
    @api maxResults = 50;
    @api showDetails = false;

    @track searchKey = '';
    @track selectedCategory = '';
    @track selectedVertical = '';
    @track products = [];
    @track selectedProduct = null;
    @track isLoading = false;
    @track error;
    @track categoryOptions = [];
    @track verticalOptions = [];

    columns = [
        { label: 'Product Name', fieldName: 'Name', type: 'text', sortable: true },
        { label: 'Item Code', fieldName: 'Item_Code__c', type: 'text', sortable: true },
        { label: 'Category', fieldName: 'Product_Category__c', type: 'text' },
        { label: 'Brand', fieldName: 'Brand__c', type: 'text' },
        { label: 'Make', fieldName: 'Make__c', type: 'text' },
        { label: 'Model', fieldName: 'Model__c', type: 'text' },
        { label: 'Price', fieldName: 'Standard_Price__c', type: 'currency' },
        { label: 'Tax %', fieldName: 'Tax__c', type: 'percent',
          typeAttributes: { maximumFractionDigits: 2 } },
        { label: 'HSN Code', fieldName: 'HSN_Code__c', type: 'text' }
    ];

    @wire(getProductCategories)
    wiredCategories({ data, error }) {
        if (data) {
            this.categoryOptions = [
                { label: 'All Categories', value: '' },
                ...data.map(cat => ({ label: cat, value: cat }))
            ];
        }
        if (error) {
            console.error('Error loading categories:', error);
        }
    }

    @wire(getProductFamilies)
    wiredFamilies({ data, error }) {
        if (data) {
            this.verticalOptions = [
                { label: 'All Families', value: '' },
                ...data.map(v => ({ label: v, value: v }))
            ];
        }
        if (error) {
            console.error('Error loading product families:', error);
        }
    }

    handleSearchKeyChange(event) {
        this.searchKey = event.target.value;
    }

    handleCategoryChange(event) {
        this.selectedCategory = event.detail.value;
        this.doSearch();
    }

    handleVerticalChange(event) {
        this.selectedVertical = event.detail.value;
        this.doSearch();
    }

    handleSearch() {
        this.doSearch();
    }

    handleKeyUp(event) {
        if (event.key === 'Enter') {
            this.doSearch();
        }
    }

    doSearch() {
        if (this.searchKey.length > 0 && this.searchKey.length < 2) {
            return;
        }
        this.isLoading = true;
        this.error = undefined;

        searchProducts({
            searchKey: this.searchKey,
            category: this.selectedCategory,
            vertical: this.selectedVertical,
            limitVal: this.maxResults
        })
            .then(result => {
                this.products = result;
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error.body ? error.body.message : 'An error occurred while searching products.';
                this.products = [];
                this.isLoading = false;
            });
    }

    handleRowSelection(event) {
        const selectedRows = event.detail.selectedRows;
        if (selectedRows.length > 0) {
            this.loadProductDetails(selectedRows[0].Id);
        }
    }

    loadProductDetails(productId) {
        this.isLoading = true;
        getProductDetails({ productId: productId })
            .then(result => {
                this.selectedProduct = result;
                this.isLoading = false;
                // Dispatch event for parent component
                this.dispatchEvent(new CustomEvent('productselect', {
                    detail: { product: result }
                }));
            })
            .catch(error => {
                this.error = error.body ? error.body.message : 'Error loading product details.';
                this.isLoading = false;
            });
    }

    handleImageError(event) {
        event.target.style.display = 'none';
    }

    handleClearSelection() {
        this.selectedProduct = null;
        this.dispatchEvent(new CustomEvent('productclear'));
    }

    get hasProducts() {
        return this.products && this.products.length > 0;
    }

    get noResults() {
        return !this.isLoading && this.products && this.products.length === 0 && this.searchKey.length >= 2;
    }

    get resultCount() {
        return this.products ? this.products.length : 0;
    }

    connectedCallback() {
        this.doSearch();
    }
}