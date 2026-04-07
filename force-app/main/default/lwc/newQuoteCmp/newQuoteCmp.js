import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getOpportunityContext from '@salesforce/apex/QuoteBuilderController.getOpportunityContext';
import getQuoteForEdit from '@salesforce/apex/QuoteBuilderController.getQuoteForEdit';
import getShippingAddresses from '@salesforce/apex/QuoteBuilderController.getShippingAddresses';
import searchProducts from '@salesforce/apex/QuoteBuilderController.searchProducts';
import saveQuoteLineItems from '@salesforce/apex/QuoteBuilderController.saveQuoteLineItems';
import updateQuoteLineItems from '@salesforce/apex/QuoteBuilderController.updateQuoteLineItems';

let rowCounter = 0;

export default class NewQuoteCmp extends NavigationMixin(LightningElement) {
    @api recordId;

    // Mode
    isEditMode = false;
    editRecordId = null;
    defaultOpportunityId = null;

    // State
    isLoading = false;
    isSaving = false;

    // Context
    pricebookId;
    currencyCode = 'INR';
    accountId;
    accountName = '';

    // Bill To address fields (pre-populated from Account)
    billingName = '';
    billingStreet = '';
    billingCity = '';
    billingState = '';
    billingPostalCode = '';
    billingCountry = '';

    // Ship To address fields (from Shipping_Address__c selector)
    shippingName = '';
    shippingStreet = '';
    shippingCity = '';
    shippingState = '';
    shippingPostalCode = '';
    shippingCountry = '';

    // Shipping address picker
    @track shippingAddresses = [];
    selectedShippingAddressId = '';

    // Search
    searchTerm = '';
    categoryFilter = '';
    @track searchResults = [];
    showSearchResults = false;

    // Line items
    @track lineItems = [];

    // Internal charges
    packingCharges = 0;
    transportCharges = 0;
    warrantyCost = 0;
    installationCost = 0;
    trainingCost = 0;

    // ===== PICKLIST OPTIONS =====

    get taxTypeOptions() {
        return [
            { label: 'GST', value: 'GST' },
            { label: 'IGST', value: 'IGST' },
            { label: 'Exempt', value: 'Exempt' }
        ];
    }

    get categoryOptions() {
        return [
            { label: 'All Categories', value: '' },
            { label: 'Medical Equipment', value: 'Medical Equipment' },
            { label: 'Surgical Instruments', value: 'Surgical Instruments' },
            { label: 'Lab Equipment', value: 'Lab Equipment' },
            { label: 'Consumables', value: 'Consumables' },
            { label: 'Services', value: 'Services' },
            { label: 'Spares', value: 'Spares' }
        ];
    }

    get shippingAddressOptions() {
        return this.shippingAddresses.map(addr => ({
            label: addr.displayLabel,
            value: addr.addressId
        }));
    }

    // ===== COMPUTED PROPERTIES =====

    get hasLineItems() { return this.lineItems.length > 0; }
    get lineItemCount() { return this.lineItems.length; }
    get hasSearchResults() { return this.searchResults.length > 0; }
    get noSearchResults() { return this.showSearchResults && this.searchResults.length === 0; }
    get isSearchDisabled() { return !this.searchTerm || this.searchTerm.length < 2; }
    get isSaveDisabled() { return this.isSaving || this.lineItems.length === 0; }
    get pageTitle() { return this.isEditMode ? 'Edit Quote' : 'Create Quote'; }
    get saveButtonLabel() { return this.isSaving ? 'Saving...' : (this.isEditMode ? 'Update Quote' : 'Save Quote'); }
    get hasShippingAddresses() { return this.shippingAddresses.length > 0; }

    // ===== CALCULATIONS =====

    get subtotal() {
        return this.lineItems.reduce((sum, item) => {
            return sum + ((item.unitPrice || 0) * (item.quantity || 0));
        }, 0);
    }

    get totalDiscount() {
        return this.lineItems.reduce((sum, item) => {
            const base = (item.unitPrice || 0) * (item.quantity || 0);
            return sum + (base * ((item.discount || 0) / 100));
        }, 0);
    }

    get totalTax() {
        return this.lineItems.reduce((sum, item) => {
            if (item.taxType === 'Exempt') return sum;
            const base = (item.unitPrice || 0) * (item.quantity || 0);
            const afterDiscount = base - (base * ((item.discount || 0) / 100));
            return sum + (afterDiscount * ((item.taxPercent || 0) / 100));
        }, 0);
    }

    get totalCharges() {
        return (parseFloat(this.packingCharges) || 0) +
               (parseFloat(this.transportCharges) || 0) +
               (parseFloat(this.warrantyCost) || 0) +
               (parseFloat(this.installationCost) || 0) +
               (parseFloat(this.trainingCost) || 0);
    }

    get grandTotal() {
        return this.subtotal - this.totalDiscount + this.totalTax + this.totalCharges;
    }

    // ===== LIFECYCLE =====

    connectedCallback() {
        this.detectModeAndLoad();
    }

    async detectModeAndLoad() {
        if (!this.recordId) return;

        this.isLoading = true;
        const idPrefix = this.recordId.substring(0, 3);

        if (idPrefix === '0Q0') {
            this.isEditMode = true;
            this.editRecordId = this.recordId;
            await this.loadQuoteLineItems();
        } else {
            this.isEditMode = false;
            this.defaultOpportunityId = this.recordId;
            await this.loadOpportunityContext();
        }

        this.isLoading = false;
    }

    async loadOpportunityContext() {
        try {
            const data = await getOpportunityContext({ opportunityId: this.recordId });
            this.pricebookId = data.pricebookId;
            this.currencyCode = data.currencyCode || 'INR';
            this.accountId = data.accountId;
            this.accountName = data.accountName || '';

            // Pre-populate Bill To from Account billing address
            this.billingName = data.billingName || '';
            this.billingStreet = data.billingStreet || '';
            this.billingCity = data.billingCity || '';
            this.billingState = data.billingState || '';
            this.billingPostalCode = data.billingPostalCode || '';
            this.billingCountry = data.billingCountry || '';

            // Fetch shipping addresses for the Account
            if (this.accountId) {
                await this.loadShippingAddresses(this.accountId);
            }
        } catch (error) {
            this.showError('Error loading opportunity', this.reduceErrors(error));
        }
    }

    async loadQuoteLineItems() {
        try {
            const data = await getQuoteForEdit({ quoteId: this.editRecordId });
            this.pricebookId = data.pricebookId;
            this.accountId = data.accountId;

            // Fetch shipping addresses for edit mode too
            if (this.accountId) {
                await this.loadShippingAddresses(this.accountId);
            }

            if (data.lineItems && data.lineItems.length > 0) {
                this.lineItems = data.lineItems.map((item, index) => {
                    rowCounter++;
                    const base = (item.unitPrice || 0) * (item.quantity || 0);
                    const discountAmt = base * ((item.discount || 0) / 100);
                    const afterDiscount = base - discountAmt;
                    const taxAmt = item.taxType === 'Exempt' ? 0 : afterDiscount * ((item.taxPercent || 0) / 100);

                    return {
                        rowId: 'row-' + rowCounter,
                        rowNumber: index + 1,
                        productId: item.productId,
                        pricebookEntryId: item.pricebookEntryId,
                        productName: item.productName,
                        productCode: item.productCode,
                        uom: item.uom || 'Nos',
                        quantity: item.quantity,
                        unitPrice: item.unitPrice,
                        discount: item.discount || 0,
                        taxPercent: item.taxPercent || 0,
                        taxPercentDisplay: (item.taxPercent || 0) + '%',
                        taxType: item.taxType || 'GST',
                        lineTotal: afterDiscount + taxAmt,
                        lineDescription: item.lineDescription || '',
                        detailedDescription: item.detailedDescription || ''
                    };
                });
            }
        } catch (error) {
            this.showError('Error loading quote', this.reduceErrors(error));
        }
    }

    async loadShippingAddresses(accountId) {
        try {
            const addresses = await getShippingAddresses({ accountId: accountId });
            this.shippingAddresses = addresses || [];

            // Auto-select first address if available and in new mode
            if (!this.isEditMode && this.shippingAddresses.length > 0) {
                this.selectedShippingAddressId = this.shippingAddresses[0].addressId;
                this.applyShippingAddress(this.shippingAddresses[0]);
            }
        } catch (error) {
            console.warn('Could not load shipping addresses:', error);
            this.shippingAddresses = [];
        }
    }

    // ===== ADDRESS HANDLERS =====

    handleBillingFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.target.value;
    }

    handleShippingFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.target.value;
    }

    handleShippingAddressSelect(event) {
        this.selectedShippingAddressId = event.detail.value;
        const selected = this.shippingAddresses.find(a => a.addressId === this.selectedShippingAddressId);
        if (selected) {
            this.applyShippingAddress(selected);
        }
    }

    applyShippingAddress(addr) {
        this.shippingName = addr.name || '';
        this.shippingStreet = addr.street || '';
        this.shippingCity = addr.city || '';
        this.shippingState = addr.state || '';
        this.shippingPostalCode = addr.postalCode || '';
        this.shippingCountry = addr.country || '';
    }

    // ===== FORM HANDLERS =====

    handleFormSubmit(event) {
        event.preventDefault();

        const errors = this.validateLineItems();
        if (errors.length > 0) {
            this.showError('Validation Error', errors.join('\n'));
            return;
        }

        const fields = event.detail.fields;

        // Inject Pricebook2Id
        fields.Pricebook2Id = this.pricebookId;

        // Inject Bill To address fields
        fields.BillingName = this.billingName;
        fields.BillingStreet = this.billingStreet;
        fields.BillingCity = this.billingCity;
        fields.BillingState = this.billingState;
        fields.BillingPostalCode = this.billingPostalCode;
        fields.BillingCountry = this.billingCountry;

        // Inject Ship To address fields
        fields.ShippingName = this.shippingName;
        fields.ShippingStreet = this.shippingStreet;
        fields.ShippingCity = this.shippingCity;
        fields.ShippingState = this.shippingState;
        fields.ShippingPostalCode = this.shippingPostalCode;
        fields.ShippingCountry = this.shippingCountry;

        // Inject internal charge fields
        fields.Packing_Charge__c = this.packingCharges || 0;
        fields.Internal_Transport_Cost__c = this.transportCharges || 0;
        fields.Warrantee_Cost__c = this.warrantyCost || 0;
        fields.Installation_Cost__c = this.installationCost || 0;
        fields.Traning_Cost__c = this.trainingCost || 0;

        // Set defaults for new quotes
        if (!this.isEditMode) {
            fields.Status = 'Draft';
            fields.Price_Status__c = 'Draft';
        }

        this.isSaving = true;
        this.isLoading = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    async handleFormSuccess(event) {
        const quoteId = event.detail.id;

        try {
            const lineItemsPayload = this.lineItems.map(item => ({
                productId: item.productId,
                pricebookEntryId: item.pricebookEntryId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: item.discount,
                taxType: item.taxType,
                lineDescription: item.lineDescription,
                detailedDescription: item.detailedDescription
            }));

            if (this.isEditMode) {
                await updateQuoteLineItems({
                    quoteId: quoteId,
                    lineItemsJSON: JSON.stringify(lineItemsPayload)
                });
                this.showSuccess('Quote Updated', 'Quote and line items updated successfully.');
            } else {
                await saveQuoteLineItems({
                    quoteId: quoteId,
                    lineItemsJSON: JSON.stringify(lineItemsPayload)
                });
                this.showSuccess('Quote Created', 'Quote and line items created successfully.');
            }

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: quoteId,
                    objectApiName: 'Quote',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showError('Line Items Save Failed',
                'Quote header was saved but line items failed: ' + this.reduceErrors(error) +
                '. Please add line items from the Quote record page.');
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: quoteId,
                    objectApiName: 'Quote',
                    actionName: 'view'
                }
            });
        } finally {
            this.isSaving = false;
            this.isLoading = false;
        }
    }

    handleFormError(event) {
        this.isSaving = false;
        this.isLoading = false;
        const message = event.detail?.message || 'An error occurred while saving the quote.';
        this.showError('Save Failed', message);
    }

    // ===== SEARCH HANDLERS =====

    handleSearchTermChange(event) { this.searchTerm = event.target.value; }
    handleCategoryFilterChange(event) { this.categoryFilter = event.detail.value; }

    async handleSearch() {
        if (this.isSearchDisabled) return;

        this.isLoading = true;
        this.showSearchResults = true;

        try {
            const results = await searchProducts({
                searchTerm: this.searchTerm,
                pricebookId: this.pricebookId,
                category: this.categoryFilter || null
            });

            this.searchResults = results.map(r => ({
                ...r,
                formattedPrice: this.formatCurrency(r.unitPrice),
                formattedTax: r.taxPercent != null ? r.taxPercent + '%' : '0%'
            }));
        } catch (error) {
            this.showError('Search failed', this.reduceErrors(error));
            this.searchResults = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ===== LINE ITEM HANDLERS =====

    handleAddProduct(event) {
        const pbeId = event.currentTarget.dataset.id;
        const product = this.searchResults.find(p => p.pricebookEntryId === pbeId);
        if (!product) return;

        if (this.lineItems.find(item => item.pricebookEntryId === pbeId)) {
            this.showError('Duplicate Product', 'This product is already in the quote. Update the quantity instead.');
            return;
        }

        rowCounter++;
        const newItem = {
            rowId: 'row-' + rowCounter,
            rowNumber: this.lineItems.length + 1,
            productId: product.productId,
            pricebookEntryId: product.pricebookEntryId,
            productName: product.productName,
            productCode: product.productCode,
            uom: product.uom || 'Nos',
            quantity: 1,
            unitPrice: product.unitPrice,
            discount: 0,
            taxPercent: product.taxPercent || 0,
            taxPercentDisplay: (product.taxPercent || 0) + '%',
            taxType: 'GST',
            lineTotal: product.unitPrice,
            lineDescription: product.lineDescription || '',
            detailedDescription: product.detailedDescription || ''
        };

        this.lineItems = [...this.lineItems, newItem];
        this.showSuccess('Product Added', product.productName + ' added to the quote.');
    }

    handleRemoveLineItem(event) {
        const rowId = event.currentTarget.dataset.rowId;
        this.lineItems = this.lineItems
            .filter(item => item.rowId !== rowId)
            .map((item, index) => ({ ...item, rowNumber: index + 1 }));
    }

    handleLineItemChange(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const field = event.currentTarget.dataset.field;
        let value = field === 'taxType' ? event.detail.value : event.target.value;

        this.lineItems = this.lineItems.map(item => {
            if (item.rowId === rowId) {
                const updated = { ...item };

                if (field === 'quantity') {
                    updated.quantity = parseFloat(value) || 0;
                } else if (field === 'discount') {
                    updated.discount = parseFloat(value) || 0;
                } else if (field === 'taxType') {
                    updated.taxType = value;
                }

                const base = updated.unitPrice * updated.quantity;
                const discountAmt = base * (updated.discount / 100);
                const afterDiscount = base - discountAmt;
                const taxAmt = updated.taxType === 'Exempt' ? 0 : afterDiscount * ((updated.taxPercent || 0) / 100);
                updated.lineTotal = afterDiscount + taxAmt;

                return updated;
            }
            return item;
        });
    }

    // ===== CHARGE HANDLERS =====

    handleChargeChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = parseFloat(event.target.value) || 0;
    }

    // ===== CANCEL =====

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());

        if (this.isEditMode) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.editRecordId,
                    objectApiName: 'Quote',
                    actionName: 'view'
                }
            });
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Opportunity',
                    actionName: 'view'
                }
            });
        }
    }

    // ===== VALIDATION =====

    validateLineItems() {
        const errors = [];

        if (this.lineItems.length === 0) {
            errors.push('At least one line item is required.');
        }

        for (const item of this.lineItems) {
            if (!item.quantity || item.quantity <= 0) {
                errors.push(`Quantity for "${item.productName}" must be greater than 0.`);
            }
            if (item.discount < 0 || item.discount > 100) {
                errors.push(`Discount for "${item.productName}" must be between 0 and 100.`);
            }
            if (!item.unitPrice || item.unitPrice <= 0) {
                errors.push(`Unit price for "${item.productName}" is not available.`);
            }
        }

        return errors;
    }

    // ===== UTILITY =====

    formatCurrency(value) {
        if (value == null) return '0.00';
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: this.currencyCode || 'INR',
            minimumFractionDigits: 2
        }).format(value);
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        return 'An unexpected error occurred.';
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error', mode: 'sticky' }));
    }
}
