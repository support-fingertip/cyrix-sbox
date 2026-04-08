import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getOpportunityContext from '@salesforce/apex/QuoteBuilderController.getOpportunityContext';
import getQuoteForEdit from '@salesforce/apex/QuoteBuilderController.getQuoteForEdit';
import getShippingAddresses from '@salesforce/apex/QuoteBuilderController.getShippingAddresses';
import searchProducts from '@salesforce/apex/QuoteBuilderController.searchProducts';
import getPricebooks from '@salesforce/apex/QuoteBuilderController.getPricebooks';
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

    // Default values for new quote (auto-populate Bill To from Account)
    defaultValues = {};

    // Pricebook picklist
    @track pricebookOptions = [];

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
    insuranceCost = 0;

    // ===== PICKLIST OPTIONS =====

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
    get quoteName() { return this.isEditMode ? undefined : 'Auto'; }
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
               (parseFloat(this.insuranceCost) || 0) +
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

        // Load pricebook options for the picklist
        await this.loadPricebooks();

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

            // === AUTO-POPULATE BILL TO ADDRESS FROM ACCOUNT ===
            if (!this.isEditMode && this.accountId) {
                this.defaultValues = {
                    BillingName: data.billingName || '',
                    BillingStreet: data.billingStreet || '',
                    BillingCity: data.billingCity || '',
                    BillingState: data.billingState || '',
                    BillingPostalCode: data.billingPostalCode || '',
                    BillingCountry: data.billingCountry || ''   // ISO code
                };
            }

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

            // Populate internal charges from saved Quote data
            this.packingCharges = data.packingCharge || 0;
            this.transportCharges = data.transportCost || 0;
            this.warrantyCost = data.warrantyCost || 0;
            this.installationCost = data.installationCost || 0;
            this.trainingCost = data.trainingCost || 0;
            this.insuranceCost = data.insuranceCost || 0;

            if (this.accountId) {
                await this.loadShippingAddresses(this.accountId);
            }

            if (data.lineItems && data.lineItems.length > 0) {
                this.lineItems = data.lineItems.map((item, index) => {
                    rowCounter++;
                    const base = (item.unitPrice || 0) * (item.quantity || 0);
                    const discountAmt = base * ((item.discount || 0) / 100);
                    const afterDiscount = base - discountAmt;
                    const taxAmt = afterDiscount * ((item.taxPercent || 0) / 100);

                    return {
                        rowId: 'row-' + rowCounter,
                        rowNumber: index + 1,
                        productId: item.productId,
                        pricebookEntryId: item.pricebookEntryId,
                        productName: item.productName,
                        productCode: item.productCode,
                        uom: item.uom || 'Nos',
                        quantity: item.quantity,
                        listPrice: item.listPrice || item.unitPrice,
                        unitPrice: item.unitPrice,
                        discount: item.discount || 0,
                        maxDiscount: item.maxDiscount || 0,
                        taxPercent: item.taxPercent || 0,
                        taxPercentDisplay: (item.taxPercent || 0) + '%',
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

            // === AUTO-SELECT FIRST SHIPPING ADDRESS FOR NEW QUOTES ===
            if (!this.isEditMode && this.shippingAddresses.length > 0) {
                this.selectedShippingAddressId = this.shippingAddresses[0].addressId;
                this.applyShippingAddress(this.shippingAddresses[0]);
            }
        } catch (error) {
            console.warn('Could not load shipping addresses:', error);
            this.shippingAddresses = [];
        }
    }

    async loadPricebooks() {
        try {
            const pricebooks = await getPricebooks();
            this.pricebookOptions = (pricebooks || []).map(pb => ({
                label: pb.pricebookName,
                value: pb.pricebookId
            }));
        } catch (error) {
            console.warn('Could not load pricebooks:', error);
            this.pricebookOptions = [];
        }
    }

    handlePricebookChange(event) {
        this.pricebookId = event.detail.value;
        // Clear existing search results when pricebook changes
        this.searchResults = [];
        this.showSearchResults = false;
    }

    // ===== SHIPPING ADDRESS HANDLER =====

    handleShippingAddressSelect(event) {
        this.selectedShippingAddressId = event.detail.value;
        const selected = this.shippingAddresses.find(a => a.addressId === this.selectedShippingAddressId);
        if (selected) {
            this.applyShippingAddress(selected);
        }
    }

    applyShippingAddress(addr) {
        // Set the individual components of the compound ShippingAddress field
        const fields = {
            ShippingName: addr.name || '',
            ShippingStreet: addr.street || '',
            ShippingCity: addr.city || '',
            ShippingState: addr.state || '',
            ShippingPostalCode: addr.postalCode || '',
            ShippingCountry: addr.country || ''   // ISO code
        };

        // Update each field imperatively
        for (const [fieldName, value] of Object.entries(fields)) {
            const fieldElement = this.template.querySelector(`lightning-input-field[field-name="${fieldName}"]`);
            if (fieldElement) {
                fieldElement.value = value;
                fieldElement.dispatchEvent(new CustomEvent('change', { detail: { value } }));
            }
        }

        // Force the compound ShippingAddress field to refresh
        setTimeout(() => {
            const shippingAddressField = this.template.querySelector('lightning-input-field[field-name="ShippingAddress"]');
            if (shippingAddressField) {
                const currentValue = shippingAddressField.value;
                shippingAddressField.value = '';
                shippingAddressField.dispatchEvent(new CustomEvent('change', { detail: { value: '' } }));
                shippingAddressField.value = currentValue;
                shippingAddressField.dispatchEvent(new CustomEvent('change', { detail: { value: currentValue } }));
            }
        }, 100);
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

        // Set placeholder Name (trigger auto-generates the actual quote name)
        if (!this.isEditMode) {
            fields.Name = 'Auto';
        }

        // Inject Pricebook2Id
        fields.Pricebook2Id = this.pricebookId;

        // Inject internal charge fields (custom fields on Quote)
        fields.Packing_Charge__c = this.packingCharges || 0;
        fields.Internal_Transport_Cost__c = this.transportCharges || 0;
        fields.Warrantee_Cost__c = this.warrantyCost || 0;
        fields.Installation_Cost__c = this.installationCost || 0;
        fields.Traning_Cost__c = this.trainingCost || 0;
        fields.Insurance_Cost__c = this.insuranceCost || 0;

        // Inject computed totals
        fields.Total_Internal_Charges__c = this.totalCharges || 0;

        // Total pricebook price = sum of (listPrice * quantity) across all line items
        const totalPricebookPrice = this.lineItems.reduce((sum, item) => {
            return sum + ((item.listPrice || 0) * (item.quantity || 0));
        }, 0);
        fields.Total_Pricebook_Price__c = totalPricebookPrice;

        // Set defaults for new quotes
        if (!this.isEditMode) {
            fields.Status = 'Draft';
        }

        this.isSaving = true;
        this.isLoading = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    async handleFormSuccess(event) {
        const quoteId = event.detail.id;

        try {
            const lineItemsPayload = this.lineItems.map(item => {
                const base = (item.unitPrice || 0) * (item.quantity || 0);
                const discountAmt = base * ((item.discount || 0) / 100);
                const afterDiscount = base - discountAmt;
                const taxAmt = afterDiscount * ((item.taxPercent || 0) / 100);
                return {
                    productId: item.productId,
                    pricebookEntryId: item.pricebookEntryId,
                    quantity: item.quantity,
                    unitPrice: item.unitPrice,
                    discount: item.discount,
                    taxPercent: item.taxPercent || 0,
                    taxAmount: Math.round(taxAmt * 100) / 100,
                    maxDiscount: item.maxDiscount || 0,
                    lineDescription: item.lineDescription,
                    detailedDescription: item.detailedDescription
                };
            });

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

            // Close the quick action modal
            this.dispatchEvent(new CloseActionScreenEvent());

            // Navigate after modal closes
            setTimeout(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: quoteId,
                        objectApiName: 'Quote',
                        actionName: 'view'
                    }
                });
            }, 300);

        } catch (error) {
            this.showError(
                'Line Items Save Failed',
                'Quote header was saved but line items failed: ' + this.reduceErrors(error) +
                '. Please add line items from the Quote record page.'
            );
            // Stay on the form, do not close modal
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
        console.error('Form error:', JSON.stringify(event.detail));
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
            listPrice: product.unitPrice,
            unitPrice: product.unitPrice,
            discount: 0,
            maxDiscount: product.maxDiscount || 0,
            taxPercent: product.taxPercent || 0,
            taxPercentDisplay: (product.taxPercent || 0) + '%',
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
        const value = event.target.value;

        this.lineItems = this.lineItems.map(item => {
            if (item.rowId === rowId) {
                const updated = { ...item };

                if (field === 'quantity') {
                    updated.quantity = parseFloat(value) || 0;
                } else if (field === 'unitPrice') {
                    updated.unitPrice = parseFloat(value) || 0;
                } else if (field === 'discount') {
                    updated.discount = parseFloat(value) || 0;
                }

                const base = updated.unitPrice * updated.quantity;
                const discountAmt = base * (updated.discount / 100);
                const afterDiscount = base - discountAmt;
                const taxAmt = afterDiscount * ((updated.taxPercent || 0) / 100);
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

        setTimeout(() => {
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
        }, 300);
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
        if (error?.body?.fieldErrors) {
            const fieldMsgs = Object.values(error.body.fieldErrors).flat().map(e => e.message);
            if (fieldMsgs.length) return fieldMsgs.join(', ');
        }
        if (error?.body?.pageErrors) {
            const pageMsgs = error.body.pageErrors.map(e => e.message);
            if (pageMsgs.length) return pageMsgs.join(', ');
        }
        if (error?.message) return error.message;
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        console.error('Unhandled error format:', JSON.stringify(error));
        return 'An unexpected error occurred.';
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error', mode: 'sticky' }));
    }
}