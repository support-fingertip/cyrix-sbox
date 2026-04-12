import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getOpportunityContext from '@salesforce/apex/QuoteBuilderController.getOpportunityContext';
import getQuoteForEdit from '@salesforce/apex/QuoteBuilderController.getQuoteForEdit';
import getShippingAddresses from '@salesforce/apex/QuoteBuilderController.getShippingAddresses';
import searchProductsWithBestPrice from '@salesforce/apex/QuoteBuilderController.searchProductsWithBestPrice';
import saveQuoteLineItems from '@salesforce/apex/QuoteBuilderController.saveQuoteLineItems';
import updateQuoteLineItems from '@salesforce/apex/QuoteBuilderController.updateQuoteLineItems';
import savePaymentTerms from '@salesforce/apex/QuoteBuilderController.savePaymentTerms';

let rowCounter = 0;
let ptCounter = 0;

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
    regionId;

    // Default values for new quote
    defaultValues = {};

    // Address objects for custom address input
    @track billingAddress = { name: '', street: '', city: '', state: '', postalCode: '', country: 'IN' };
    @track shippingAddress = { name: '', street: '', city: '', state: '', postalCode: '', country: 'IN' };

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

    // Payment terms
    @track paymentTerms = [];

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
    get hasPaymentTerms() { return this.paymentTerms.length > 0; }
    get paymentTermCount() { return this.paymentTerms.length; }
    get totalPercentage() {
        return this.paymentTerms.reduce((sum, t) => sum + (parseFloat(t.percentage) || 0), 0);
    }
    get percentageOverflow() { return this.totalPercentage > 100; }
    // In edit mode, return undefined so an empty defaultValues object can't
    // interfere with LDS auto-loading the saved Quote address subfields.
    get formDefaultValues() { return this.isEditMode ? undefined : this.defaultValues; }

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
            // Use Standard Pricebook for quote (auto-pricing selects best price per line item)
            this.pricebookId = data.standardPricebookId || data.pricebookId;
            this.currencyCode = data.currencyCode || 'INR';
            this.accountId = data.accountId;
            this.accountName = data.accountName || '';
            this.regionId = data.regionId;

            // === AUTO-POPULATE BILL TO ADDRESS FROM ACCOUNT ===
            if (!this.isEditMode && this.accountId) {
                this.billingAddress = {
                    name: data.billingName || '',
                    street: data.billingStreet || '',
                    city: data.billingCity || '',
                    state: data.billingState || '',
                    postalCode: data.billingPostalCode || '',
                    country: data.billingCountry || 'IN'
                };
            }

            // Fetch shipping addresses for the Account
            if (this.accountId) {
                await this.loadShippingAddresses(this.accountId);
            }

            // === AUTO-POPULATE PAYMENT TERMS FROM MASTER ===
            // Match on Opportunity vertical vs Payment_Terms_Master.Type; blank Type acts as fallback.
            if (!this.isEditMode && data.defaultPaymentTerms && data.defaultPaymentTerms.length > 0) {
                this.paymentTerms = data.defaultPaymentTerms.map((t, index) => {
                    ptCounter++;
                    return {
                        ptId: 'pt-' + ptCounter,
                        rowNumber: index + 1,
                        paymentTerm: t.paymentTerm || '',
                        percentage: t.percentage || 0
                    };
                });
            }
        } catch (error) {
            this.showError('Error loading opportunity', this.reduceErrors(error));
        }
    }

    async loadQuoteLineItems() {
        try {
            const data = await getQuoteForEdit({ quoteId: this.editRecordId });
            this.pricebookId = data.standardPricebookId || data.pricebookId;
            this.accountId = data.accountId;
            this.accountName = data.accountName || '';
            this.regionId = data.regionId;
            this.defaultOpportunityId = data.opportunityId;

            // Populate address objects from saved quote
            this.billingAddress = {
                name: data.billingName || '',
                street: data.billingStreet || '',
                city: data.billingCity || '',
                state: data.billingState || '',
                postalCode: data.billingPostalCode || '',
                country: data.billingCountry || 'IN'
            };
            this.shippingAddress = {
                name: data.shippingName || '',
                street: data.shippingStreet || '',
                city: data.shippingCity || '',
                state: data.shippingState || '',
                postalCode: data.shippingPostalCode || '',
                country: data.shippingCountry || 'IN'
            };

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

                    const disc = item.discount || 0;
                    const maxDisc = item.maxDiscount;
                    const priceStatus = item.priceStatus || this.computePriceStatus(disc, maxDisc);

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
                        discount: disc,
                        taxPercent: item.taxPercent || 0,
                        taxPercentDisplay: (item.taxPercent || 0) + '%',
                        maxDiscount: maxDisc,
                        maxDiscountDisplay: maxDisc != null ? maxDisc + '%' : '',
                        priceStatus: priceStatus,
                        priceStatusBadgeClass: this.getPriceStatusBadgeClass(priceStatus),
                        isApprovalRequired: priceStatus === 'Approval Required',
                        lineTotal: afterDiscount + taxAmt,
                        lineDescription: item.lineDescription || '',
                        detailedDescription: item.detailedDescription || '',
                        sourcePricebookId: item.sourcePricebookId || null,
                        sourcePricebookName: item.sourcePricebookName || '',
                        priceBadgeClass: this.getPriceBadgeClass(item.sourcePricebookName),
                        priceBadgeLabel: item.sourcePricebookName || '',
                        hasPriceSource: !!item.sourcePricebookName
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


    // ===== SHIPPING ADDRESS HANDLER =====

    handleShippingAddressSelect(event) {
        this.selectedShippingAddressId = event.detail.value;
        const selected = this.shippingAddresses.find(a => a.addressId === this.selectedShippingAddressId);
        if (selected) {
            this.applyShippingAddress(selected);
        }
    }

    applyShippingAddress(addr) {
        this.shippingAddress = {
            name: addr.name || '',
            street: addr.street || '',
            city: addr.city || '',
            state: addr.state || '',
            postalCode: addr.postalCode || '',
            country: addr.country || 'IN'
        };
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

    // ===== PAYMENT TERM HANDLERS =====

    handleAddPaymentTerm() {
        ptCounter++;
        this.paymentTerms = [
            ...this.paymentTerms,
            {
                ptId: 'pt-' + ptCounter,
                rowNumber: this.paymentTerms.length + 1,
                paymentTerm: '',
                percentage: 0
            }
        ];
    }

    handleRemovePaymentTerm(event) {
        const ptId = event.currentTarget.dataset.ptId;
        this.paymentTerms = this.paymentTerms
            .filter(t => t.ptId !== ptId)
            .map((t, index) => ({ ...t, rowNumber: index + 1 }));
    }

    handlePaymentTermChange(event) {
        const ptId = event.currentTarget.dataset.ptId;
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;

        this.paymentTerms = this.paymentTerms.map(t => {
            if (t.ptId === ptId) {
                const updated = { ...t };
                if (field === 'paymentTerm') {
                    updated.paymentTerm = value;
                } else if (field === 'percentage') {
                    updated.percentage = parseFloat(value) || 0;
                }
                return updated;
            }
            return t;
        });
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

        // Inject Billing Address
        fields.BillingName = this.billingAddress.name || '';
        fields.BillingStreet = this.billingAddress.street || '';
        fields.BillingCity = this.billingAddress.city || '';
        fields.BillingStateCode = this.billingAddress.state || '';
        fields.BillingPostalCode = this.billingAddress.postalCode || '';
        fields.BillingCountryCode = this.billingAddress.country || '';

        // Inject Shipping Address
        fields.ShippingName = this.shippingAddress.name || '';
        fields.ShippingStreet = this.shippingAddress.street || '';
        fields.ShippingCity = this.shippingAddress.city || '';
        fields.ShippingStateCode = this.shippingAddress.state || '';
        fields.ShippingPostalCode = this.shippingAddress.postalCode || '';
        fields.ShippingCountryCode = this.shippingAddress.country || '';

        // Inject internal charge fields (custom fields on Quote)
        fields.Packing_Charge__c = this.packingCharges || 0;
        fields.Internal_Transport_Cost__c = this.transportCharges || 0;
        fields.Warrantee_Cost__c = this.warrantyCost || 0;
        fields.Installation_Cost__c = this.installationCost || 0;
        fields.Traning_Cost__c = this.trainingCost || 0;
        fields.Insurance_Charge__c = this.insuranceCost || 0;   // adjust field name if needed

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
            const lineItemsPayload = this.lineItems.map(item => ({
                productId: item.productId,
                pricebookEntryId: item.pricebookEntryId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: item.discount,
                maxDiscount: item.maxDiscount,
                lineDescription: item.lineDescription,
                detailedDescription: item.detailedDescription,
                sourcePricebookId: item.sourcePricebookId || null,
                priceStatus: item.priceStatus || null
            }));

            if (this.isEditMode) {
                await updateQuoteLineItems({
                    quoteId: quoteId,
                    lineItemsJSON: JSON.stringify(lineItemsPayload)
                });
            } else {
                await saveQuoteLineItems({
                    quoteId: quoteId,
                    lineItemsJSON: JSON.stringify(lineItemsPayload)
                });
            }

            // Save payment terms (delete existing on edit, then insert current list)
            const ptPayload = this.paymentTerms
                .filter(t => t.paymentTerm && t.paymentTerm.trim() !== '')
                .map(t => ({
                    paymentTerm: t.paymentTerm,
                    percentage: t.percentage || 0
                }));
            await savePaymentTerms({
                quoteId: quoteId,
                paymentTermsJSON: JSON.stringify(ptPayload),
                deleteExisting: this.isEditMode
            });

            this.showSuccess(
                this.isEditMode ? 'Quote Updated' : 'Quote Created',
                'Quote, line items, and payment terms saved successfully.'
            );

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
            const results = await searchProductsWithBestPrice({
                searchTerm: this.searchTerm,
                category: this.categoryFilter || null,
                accountId: this.accountId || null,
                regionId: this.regionId || null
            });

            this.searchResults = results.map(r => ({
                ...r,
                formattedPrice: this.formatCurrency(r.unitPrice),
                formattedTax: r.taxPercent != null ? r.taxPercent + '%' : '0%',
                maxDiscountDisplay: r.maxDiscount != null ? r.maxDiscount + '%' : '',
                priceBadgeClass: this.getPriceBadgeClass(r.sourcePricebookType),
                priceBadgeLabel: this.getPriceBadgeLabel(r.sourcePricebookType),
                hasPriceSource: !!r.sourcePricebookType
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
        const priceStatus = this.computePriceStatus(0, product.maxDiscount);
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
            taxPercent: product.taxPercent || 0,
            taxPercentDisplay: (product.taxPercent || 0) + '%',
            maxDiscount: product.maxDiscount,
            maxDiscountDisplay: product.maxDiscount != null ? product.maxDiscount + '%' : '',
            priceStatus: priceStatus,
            priceStatusBadgeClass: this.getPriceStatusBadgeClass(priceStatus),
            isApprovalRequired: priceStatus === 'Approval Required',
            lineTotal: product.unitPrice,
            lineDescription: product.lineDescription || '',
            detailedDescription: product.detailedDescription || '',
            sourcePricebookId: product.sourcePricebookId || null,
            sourcePricebookName: product.sourcePricebook || '',
            priceBadgeClass: this.getPriceBadgeClass(product.sourcePricebookType),
            priceBadgeLabel: this.getPriceBadgeLabel(product.sourcePricebookType),
            hasPriceSource: !!product.sourcePricebookType
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

                // Only escalate the price status when the discount now exceeds the
                // max discount. Never downgrade an already Approval Required /
                // Approved line item just because other fields changed.
                if (field === 'discount'
                    && updated.maxDiscount != null
                    && updated.discount > updated.maxDiscount
                    && updated.priceStatus !== 'Approval Required'
                    && updated.priceStatus !== 'Approved') {
                    updated.priceStatus = 'Approval Required';
                    updated.priceStatusBadgeClass = this.getPriceStatusBadgeClass('Approval Required');
                    updated.isApprovalRequired = true;
                }

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

    // ===== PRICE STATUS =====

    computePriceStatus(discount, maxDiscount) {
        if (discount != null && maxDiscount != null && discount > maxDiscount) {
            return 'Approval Required';
        }
        return 'Not Required';
    }

    getPriceStatusBadgeClass(priceStatus) {
        const base = 'slds-badge';
        switch (priceStatus) {
            case 'Approval Required': return base + ' slds-theme_error';
            case 'Approved': return base + ' slds-theme_success';
            case 'Not Required':
            default: return base + ' slds-theme_shade';
        }
    }

    // ===== PRICING BADGE HELPERS =====

    getPriceBadgeClass(pricebookType) {
        const base = 'price-source-badge';
        if (!pricebookType) return base + ' price-source-standard';
        switch (pricebookType) {
            case 'Promotional Price': return base + ' price-source-promotional';
            case 'Customer Specific': return base + ' price-source-customer';
            case 'Region Specific': return base + ' price-source-region';
            case 'Dealer Price': return base + ' price-source-dealer';
            default: return base + ' price-source-standard';
        }
    }

    getPriceBadgeLabel(pricebookType) {
        if (!pricebookType) return '';
        switch (pricebookType) {
            case 'Promotional Price': return 'Promotional';
            case 'Customer Specific': return 'Customer Price';
            case 'Region Specific': return 'Region Price';
            case 'Dealer Price': return 'Dealer Price';
            case 'Standard': return 'Standard';
            default: return pricebookType;
        }
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