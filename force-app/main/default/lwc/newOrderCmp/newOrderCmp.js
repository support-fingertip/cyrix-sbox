import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getOpportunityContext from '@salesforce/apex/OrderBuilderController.getOpportunityContext';
import getAccountContext from '@salesforce/apex/OrderBuilderController.getAccountContext';
import getQuoteContext from '@salesforce/apex/OrderBuilderController.getQuoteContext';
import getOrderForEdit from '@salesforce/apex/OrderBuilderController.getOrderForEdit';
import saveOrderItems from '@salesforce/apex/OrderBuilderController.saveOrderItems';
import updateOrderItems from '@salesforce/apex/OrderBuilderController.updateOrderItems';
import savePaymentTerms from '@salesforce/apex/OrderBuilderController.savePaymentTerms';
import searchProductsWithBestPrice from '@salesforce/apex/QuoteBuilderController.searchProductsWithBestPrice';

let rowCounter = 0;
let ptCounter = 0;

export default class NewOrderCmp extends NavigationMixin(LightningElement) {
    @api recordId;

    @wire(CurrentPageReference)
    wiredPageRef(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.c__recordId && !this.recordId) {
            this.recordId = pageRef.state.c__recordId;
        }
    }

    // Mode
    isEditMode = false;
    editRecordId = null;
    defaultOpportunityId = null;
    defaultAccountId = null;

    // State
    isLoading = false;
    isSaving = false;

    // Context
    pricebookId;
    currencyCode = 'INR';
    accountId;
    accountName = '';
    regionId;

    // Address objects
    @track billingAddress = { name: '', street: '', city: '', state: '', postalCode: '', country: 'IN' };
    @track shippingAddress = { name: '', street: '', city: '', state: '', postalCode: '', country: 'IN' };

    // Search
    searchTerm = '';
    categoryFilter = '';
    @track searchResults = [];
    showSearchResults = false;

    // Line items
    @track lineItems = [];

    // Payment terms
    @track paymentTerms = [];

    // Source quote (when creating from a Quote)
    sourceQuoteId = null;

    // Defaults carried from source Quote (create mode) or edited record
    carryBusinessVertical = null;
    carryShippingMode = null;
    carryDelivery = null;
    carryContractFrom = null;
    carryContractEnd = null;

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

    // ===== COMPUTED PROPERTIES =====

    get hasLineItems() { return this.lineItems.length > 0; }
    get lineItemCount() { return this.lineItems.length; }
    get hasSearchResults() { return this.searchResults.length > 0; }
    get noSearchResults() { return this.showSearchResults && this.searchResults.length === 0; }
    get isSearchDisabled() { return !this.searchTerm || this.searchTerm.length < 2; }
    get isSaveDisabled() { return this.isSaving || this.lineItems.length === 0; }
    get pageTitle() { return this.isEditMode ? 'Edit Order' : 'Create Order'; }
    get orderName() { return this.isEditMode ? undefined : 'Auto'; }
    get saveButtonLabel() { return this.isSaving ? 'Saving...' : (this.isEditMode ? 'Update Order' : 'Save Order'); }
    get hasPaymentTerms() { return this.paymentTerms.length > 0; }
    get paymentTermCount() { return this.paymentTerms.length; }
    get totalPercentage() {
        return this.paymentTerms.reduce((sum, t) => sum + (parseFloat(t.percentage) || 0), 0);
    }
    get percentageOverflow() { return this.totalPercentage > 100; }
    get defaultEffectiveDate() {
        if (this.isEditMode) return undefined;
        const d = new Date();
        return d.toISOString().slice(0, 10);
    }
    get defaultSourceQuoteId() { return this.sourceQuoteId || undefined; }
    get isQuoteLocked() { return this.isEditMode; }
    get defaultBusinessVertical() {
        return this.isEditMode ? undefined : (this.carryBusinessVertical || undefined);
    }
    get defaultShippingMode() {
        return this.isEditMode ? undefined : (this.carryShippingMode || undefined);
    }
    get defaultDelivery() {
        return this.isEditMode ? undefined : (this.carryDelivery || undefined);
    }
    get defaultContractFrom() {
        return this.isEditMode ? undefined : (this.carryContractFrom || undefined);
    }
    get defaultContractEnd() {
        return this.isEditMode ? undefined : (this.carryContractEnd || undefined);
    }

    // ===== CALCULATIONS =====

    get subtotal() {
        return this.lineItems.reduce((sum, item) => {
            return sum + ((item.unitPrice || 0) * (item.quantity || 0));
        }, 0);
    }

    get totalTax() {
        return this.lineItems.reduce((sum, item) => {
            const base = (item.unitPrice || 0) * (item.quantity || 0);
            return sum + (base * ((item.taxPercent || 0) / 100));
        }, 0);
    }

    get grandTotal() {
        return this.subtotal + this.totalTax;
    }

    // ===== LIFECYCLE =====

    connectedCallback() {
        this.detectModeAndLoad();
    }

    async detectModeAndLoad() {
        if (!this.recordId) return;

        this.isLoading = true;
        const idPrefix = this.recordId.substring(0, 3);

        try {
            if (idPrefix === '801') {
                // Order record - edit mode
                this.isEditMode = true;
                this.editRecordId = this.recordId;
                await this.loadOrderForEdit();
            } else if (idPrefix === '0Q0') {
                // Quote - new order from quote (carry addresses, lines, payment terms)
                this.isEditMode = false;
                this.sourceQuoteId = this.recordId;
                await this.loadQuoteContext();
            } else if (idPrefix === '006') {
                // Opportunity - new order for opportunity
                this.isEditMode = false;
                this.defaultOpportunityId = this.recordId;
                await this.loadOpportunityContext();
            } else if (idPrefix === '001') {
                // Account - new order for account
                this.isEditMode = false;
                this.defaultAccountId = this.recordId;
                await this.loadAccountContext();
            }
        } catch (error) {
            this.showError('Error loading data', this.reduceErrors(error));
        } finally {
            this.isLoading = false;
        }
    }

    async loadOpportunityContext() {
        const data = await getOpportunityContext({ opportunityId: this.recordId });
        this.pricebookId = data.standardPricebookId || data.pricebookId;
        this.currencyCode = data.currencyCode || 'INR';
        this.accountId = data.accountId;
        this.accountName = data.accountName || '';
        this.regionId = data.regionId;
        this.defaultAccountId = data.accountId;

        this.billingAddress = {
            name: data.billingName || '',
            street: data.billingStreet || '',
            city: data.billingCity || '',
            state: data.billingState || '',
            postalCode: data.billingPostalCode || '',
            country: data.billingCountry || 'IN'
        };

    }

    async loadAccountContext() {
        const data = await getAccountContext({ accountId: this.recordId });
        this.pricebookId = data.standardPricebookId || data.pricebookId;
        this.currencyCode = data.currencyCode || 'INR';
        this.accountId = data.accountId;
        this.accountName = data.accountName || '';

        this.billingAddress = {
            name: data.billingName || '',
            street: data.billingStreet || '',
            city: data.billingCity || '',
            state: data.billingState || '',
            postalCode: data.billingPostalCode || '',
            country: data.billingCountry || 'IN'
        };

    }

    async loadQuoteContext() {
        const data = await getQuoteContext({ quoteId: this.sourceQuoteId });
        // Carry the source Quote's pricebook onto the Order so QLI
        // PricebookEntryIds map cleanly to OrderItem rows.
        this.pricebookId = data.pricebookId || data.standardPricebookId;
        this.accountId = data.accountId;
        this.accountName = data.accountName || '';
        this.defaultAccountId = data.accountId;
        this.defaultOpportunityId = data.opportunityId;
        this.carryBusinessVertical = data.businessVertical;
        this.carryShippingMode = data.shippingMode;
        this.carryDelivery = data.delivery;
        this.carryContractFrom = data.contractPeriodFrom;
        this.carryContractEnd = data.contractPeriodEnd;

        this.billingAddress = {
            name: data.accountName || '',
            street: data.billingStreet || '',
            city: data.billingCity || '',
            state: data.billingState || '',
            postalCode: data.billingPostalCode || '',
            country: data.billingCountry || 'IN'
        };
        this.shippingAddress = {
            name: data.accountName || '',
            street: data.shippingStreet || '',
            city: data.shippingCity || '',
            state: data.shippingState || '',
            postalCode: data.shippingPostalCode || '',
            country: data.shippingCountry || 'IN'
        };


        if (data.lineItems && data.lineItems.length > 0) {
            this.lineItems = data.lineItems.map((item, index) => {
                rowCounter++;
                const base = (item.unitPrice || 0) * (item.quantity || 0);
                const taxAmt = base * ((item.taxPercent || 0) / 100);
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
                    taxPercent: item.taxPercent || 0,
                    taxPercentDisplay: (item.taxPercent || 0) + '%',
                    isServiceItem: item.isServiceItem === true,
                    lineTotal: base + taxAmt
                };
            });
        }

        if (data.paymentTerms && data.paymentTerms.length > 0) {
            this.paymentTerms = data.paymentTerms.map((t, index) => {
                ptCounter++;
                return {
                    ptId: 'pt-' + ptCounter,
                    rowNumber: index + 1,
                    paymentTerm: t.paymentTerm || '',
                    percentage: t.percentage || 0
                };
            });
        }
    }

    async loadOrderForEdit() {
        const data = await getOrderForEdit({ orderId: this.editRecordId });
        this.pricebookId = data.standardPricebookId || data.pricebookId;
        this.accountId = data.accountId;
        this.accountName = data.accountName || '';
        this.defaultAccountId = data.accountId;
        this.defaultOpportunityId = data.opportunityId;
        this.sourceQuoteId = data.sourceQuoteId || null;

        this.billingAddress = {
            name: data.accountName || '',
            street: data.billingStreet || '',
            city: data.billingCity || '',
            state: data.billingState || '',
            postalCode: data.billingPostalCode || '',
            country: data.billingCountry || 'IN'
        };
        this.shippingAddress = {
            name: data.accountName || '',
            street: data.shippingStreet || '',
            city: data.shippingCity || '',
            state: data.shippingState || '',
            postalCode: data.shippingPostalCode || '',
            country: data.shippingCountry || 'IN'
        };


        if (data.lineItems && data.lineItems.length > 0) {
            this.lineItems = data.lineItems.map((item, index) => {
                rowCounter++;
                const base = (item.unitPrice || 0) * (item.quantity || 0);
                const taxAmt = base * ((item.taxPercent || 0) / 100);

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
                    taxPercent: item.taxPercent || 0,
                    taxPercentDisplay: (item.taxPercent || 0) + '%',
                    isServiceItem: item.isServiceItem === true,
                    lineTotal: base + taxAmt
                };
            });
        }

        if (data.paymentTerms && data.paymentTerms.length > 0) {
            this.paymentTerms = data.paymentTerms.map((t, index) => {
                ptCounter++;
                return {
                    ptId: 'pt-' + ptCounter,
                    rowNumber: index + 1,
                    paymentTerm: t.paymentTerm || '',
                    percentage: t.percentage || 0
                };
            });
        }
    }

    // ===== ADDRESS CHANGE HANDLERS =====

    handleBillingAddressChange(event) {
        const d = event.detail || {};
        this.billingAddress = {
            name: d.name || '',
            street: d.street || '',
            city: d.city || '',
            state: d.state || '',
            postalCode: d.postalCode || '',
            country: d.country || 'IN'
        };
    }

    handleShippingAddressChange(event) {
        const d = event.detail || {};
        this.shippingAddress = {
            name: d.name || '',
            street: d.street || '',
            city: d.city || '',
            state: d.state || '',
            postalCode: d.postalCode || '',
            country: d.country || 'IN'
        };
    }

    // ===== QUOTE LOOKUP HANDLER =====

    async handleQuoteChange(event) {
        if (this.isEditMode) return;
        const newQuoteId = event.detail && event.detail.value && event.detail.value.length
            ? event.detail.value[0]
            : null;
        if (newQuoteId === (this.sourceQuoteId || null)) return;

        if (!newQuoteId) {
            this.resetQuoteCarriedData();
            return;
        }

        this.sourceQuoteId = newQuoteId;
        this.isLoading = true;
        try {
            await this.loadQuoteContext();
        } catch (error) {
            this.showError('Error loading quote', this.reduceErrors(error));
        } finally {
            this.isLoading = false;
        }
    }

    resetQuoteCarriedData() {
        this.sourceQuoteId = null;
        this.accountId = null;
        this.accountName = '';
        this.defaultAccountId = null;
        this.defaultOpportunityId = null;
        this.carryBusinessVertical = null;
        this.carryShippingMode = null;
        this.carryDelivery = null;
        this.carryContractFrom = null;
        this.carryContractEnd = null;
        this.billingAddress = { name: '', street: '', city: '', state: '', postalCode: '', country: 'IN' };
        this.shippingAddress = { name: '', street: '', city: '', state: '', postalCode: '', country: 'IN' };
        this.lineItems = [];
        this.paymentTerms = [];
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

        if (!this.isEditMode) {
            fields.Pricebook2Id = this.pricebookId;
            fields.Status = 'Draft';
        }

        fields.BillingStreet = this.billingAddress.street || '';
        fields.BillingCity = this.billingAddress.city || '';
        fields.BillingStateCode = this.billingAddress.state || '';
        fields.BillingPostalCode = this.billingAddress.postalCode || '';
        fields.BillingCountryCode = this.billingAddress.country || '';

        fields.ShippingStreet = this.shippingAddress.street || '';
        fields.ShippingCity = this.shippingAddress.city || '';
        fields.ShippingStateCode = this.shippingAddress.state || '';
        fields.ShippingPostalCode = this.shippingAddress.postalCode || '';
        fields.ShippingCountryCode = this.shippingAddress.country || '';

        this.isSaving = true;
        this.isLoading = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    async handleFormSuccess(event) {
        const orderId = event.detail.id;

        try {
            const lineItemsPayload = this.lineItems.map(item => ({
                productId: item.productId,
                pricebookEntryId: item.pricebookEntryId,
                quantity: item.quantity,
                unitPrice: item.unitPrice
            }));

            if (this.isEditMode) {
                await updateOrderItems({
                    orderId: orderId,
                    lineItemsJSON: JSON.stringify(lineItemsPayload)
                });
            } else {
                await saveOrderItems({
                    orderId: orderId,
                    lineItemsJSON: JSON.stringify(lineItemsPayload)
                });
            }

            const ptPayload = this.paymentTerms
                .filter(t => t.paymentTerm && t.paymentTerm.trim() !== '')
                .map(t => ({
                    paymentTerm: t.paymentTerm,
                    percentage: t.percentage || 0
                }));
            await savePaymentTerms({
                orderId: orderId,
                paymentTermsJSON: JSON.stringify(ptPayload),
                deleteExisting: this.isEditMode
            });

            this.showSuccess(
                this.isEditMode ? 'Order Updated' : 'Order Created',
                'Order, line items, and payment terms saved successfully.'
            );

            this.dispatchEvent(new CloseActionScreenEvent());

            setTimeout(() => {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: orderId,
                        objectApiName: 'Order',
                        actionName: 'view'
                    }
                });
            }, 300);

        } catch (error) {
            this.showError(
                'Line Items Save Failed',
                'Order header was saved but line items failed: ' + this.reduceErrors(error)
            );
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: orderId,
                    objectApiName: 'Order',
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
        const message = event.detail?.message || 'An error occurred while saving the order.';
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
            const results = await searchProductsWithBestPrice({
                searchTerm: this.searchTerm,
                category: this.categoryFilter || null,
                accountId: this.accountId || null,
                regionId: this.regionId || null
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
            this.showError('Duplicate Product', 'This product is already in the order. Update the quantity instead.');
            return;
        }

        const isService = product.isServiceItem === true;
        if (!isService && (!product.pricebookEntryId || product.unitPrice == null)) {
            this.showError(
                'Cannot add product',
                product.productName + ' does not have a pricebook entry.'
            );
            return;
        }

        rowCounter++;
        const base = (product.unitPrice || 0);
        const tax = base * ((product.taxPercent || 0) / 100);

        const newItem = {
            rowId: 'row-' + rowCounter,
            rowNumber: this.lineItems.length + 1,
            productId: product.productId,
            pricebookEntryId: product.pricebookEntryId,
            productName: product.productName,
            productCode: product.productCode,
            uom: product.uom || 'Nos',
            quantity: 1,
            listPrice: product.unitPrice || 0,
            unitPrice: product.unitPrice || 0,
            taxPercent: product.taxPercent || 0,
            taxPercentDisplay: (product.taxPercent || 0) + '%',
            isServiceItem: isService,
            lineTotal: base + tax
        };

        this.lineItems = [...this.lineItems, newItem];
        this.showSuccess('Product Added', product.productName + ' added to the order.');
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
            if (item.rowId !== rowId) return item;
            const updated = { ...item };

            if (field === 'quantity') {
                updated.quantity = parseFloat(value) || 0;
            } else if (field === 'unitPrice') {
                const raw = parseFloat(value) || 0;
                if (raw < updated.listPrice) {
                    this.showError(
                        'Sales Price below standard',
                        'Sales Price cannot be below the list price (' +
                        this.formatCurrency(updated.listPrice) + ').'
                    );
                    updated.unitPrice = updated.listPrice;
                } else {
                    updated.unitPrice = raw;
                }
            }

            const base = updated.unitPrice * updated.quantity;
            const taxAmt = base * ((updated.taxPercent || 0) / 100);
            updated.lineTotal = base + taxAmt;

            return updated;
        });
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
                        objectApiName: 'Order',
                        actionName: 'view'
                    }
                });
            } else if (this.recordId) {
                const prefix = this.recordId.substring(0, 3);
                let objectApiName = 'Order';
                if (prefix === '006') objectApiName = 'Opportunity';
                else if (prefix === '001') objectApiName = 'Account';
                else if (prefix === '0Q0') objectApiName = 'Quote';
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: this.recordId,
                        objectApiName: objectApiName,
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
            if (!item.unitPrice || item.unitPrice <= 0) {
                errors.push(`Sales Price for "${item.productName}" is not set.`);
            }
            if (item.listPrice != null && item.unitPrice < item.listPrice) {
                errors.push(
                    `Sales Price for "${item.productName}" cannot be below the list price.`
                );
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
        return 'An unexpected error occurred.';
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error', mode: 'sticky' }));
    }
}
