import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
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

    // Picks up recordId when launched from the "New Quote" Lightning Component Tab
    // (the record-home override navigates here with state.c__recordId set).
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

    // State
    isLoading = false;
    isSaving = false;

    // Context
    pricebookId;
    currencyCode = 'INR';
    accountId;
    accountName = '';
    regionId;

    // Default values for new quote (is_Active defaults to true so fresh quotes
    // are marked as the active one for the opportunity).
    defaultValues = { is_Active__c: true };

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
    // Force is_Active__c to be checked on new quote creation. In edit mode,
    // returning undefined lets lightning-input-field fall back to the saved
    // record value.
    get defaultIsActive() { return this.isEditMode ? undefined : true; }

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

    get productCostBreakdown() {
        const cats = [
            { key: 'installation', label: 'Installation', field: 'installationCostPercent' },
            { key: 'training', label: 'Training', field: 'trainingCostPercent' },
            { key: 'warranty', label: 'Warranty', field: 'warrantyCostPercent' },
            { key: 'insurance', label: 'Insurance', field: 'insuranceCostPercent' },
            { key: 'transport', label: 'Transport', field: 'transportCostPercent' },
            { key: 'promotional', label: 'Promotional', field: 'promotionalCostPercent' }
        ];
        return cats.map(c => {
            const amount = this.lineItems.reduce((sum, item) => {
                const base = (item.unitPrice || 0) * (item.quantity || 0);
                const afterDiscount = base - (base * ((item.discount || 0) / 100));
                return sum + (afterDiscount * ((item[c.field] || 0) / 100));
            }, 0);
            return { ...c, amount };
        }).filter(c => c.amount > 0);
    }

    get totalProductCosts() {
        return this.productCostBreakdown.reduce((s, c) => s + c.amount, 0);
    }

    get hasProductCosts() { return this.totalProductCosts > 0; }

    get grandTotal() {
        return this.subtotal - this.totalDiscount + this.totalTax + this.totalProductCosts;
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
                    const isService = item.isServiceItem === true;
                    // Legacy QLIs may still carry Quote-level values like 'Draft' or
                    // 'Rejected' that aren't valid on the restricted line-item picklist.
                    const VALID_LINE_STATUSES = ['Not Required', 'Approval Required', 'Approved'];
                    const priceStatus = VALID_LINE_STATUSES.includes(item.priceStatus)
                        ? item.priceStatus
                        : this.computePriceStatus(item.unitPrice, disc, item.listPrice, isService);

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
                        isServiceItem: isService,
                        priceStatus: priceStatus,
                        priceStatusBadgeClass: this.getPriceStatusBadgeClass(priceStatus),
                        isApprovalRequired: priceStatus === 'Approval Required',
                        lineTotal: afterDiscount + taxAmt,
                        lineDescription: item.lineDescription || '',
                        detailedDescription: item.detailedDescription || '',
                        sourcePricebookId: item.sourcePricebookId || null,
                        sourcePricebookName: item.sourcePricebookName || '',
                        priceBadgeClass: this.getPriceBadgeClass(item.sourcePricebookName),
                        priceBadgeLabel: this.getPriceBadgeLabel(item.sourcePricebookName),
                        hasPriceSource: !!item.sourcePricebookName,
                        managerDiscountUpTo: item.managerDiscountUpTo,
                        vpDiscountUpTo: item.vpDiscountUpTo,
                        ceoDiscountUpTo: item.ceoDiscountUpTo,
                        installationCostPercent: item.installationCostPercent,
                        insuranceCostPercent: item.insuranceCostPercent,
                        transportCostPercent: item.transportCostPercent,
                        promotionalCostPercent: item.promotionalCostPercent,
                        trainingCostPercent: item.trainingCostPercent,
                        warrantyCostPercent: item.warrantyCostPercent,
                        discountDisplay: this.buildDiscountDisplay(item),
                        discountTooltip: this.buildDiscountTooltip(item),
                        totalCostPercentDisplay: this.buildTotalCostDisplay(item),
                        costBreakdownTooltip: this.buildCostTooltip(item),
                        discountInputClass: this.getDiscountInputClass(disc, item.managerDiscountUpTo)
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
                priceBadgeClass: this.getPriceBadgeClass(r.sourcePricebookType),
                priceBadgeLabel: this.getPriceBadgeLabel(r.sourcePricebookType),
                hasPriceSource: !!r.sourcePricebookType,
                discountDisplay: this.buildDiscountDisplay(r),
                discountTooltip: this.buildDiscountTooltip(r),
                totalCostPercentDisplay: this.buildTotalCostDisplay(r),
                costBreakdownTooltip: this.buildCostTooltip(r)
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

        const isService = product.isServiceItem === true;
        if (!isService && (!product.pricebookEntryId || product.unitPrice == null)) {
            this.showError(
                'Cannot add product',
                product.productName + ' does not have a Price list5 entry. Ask an admin to create one before adding it to a quote.'
            );
            return;
        }

        rowCounter++;
        const priceStatus = this.computePriceStatus(product.unitPrice, 0, product.unitPrice, isService);
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
            discount: 0,
            taxPercent: product.taxPercent || 0,
            taxPercentDisplay: (product.taxPercent || 0) + '%',
            isServiceItem: isService,
            priceStatus: priceStatus,
            priceStatusBadgeClass: this.getPriceStatusBadgeClass(priceStatus),
            isApprovalRequired: priceStatus === 'Approval Required',
            lineTotal: (product.unitPrice || 0) * (1 + ((product.taxPercent || 0) / 100)),
            lineDescription: product.lineDescription || '',
            detailedDescription: product.detailedDescription || '',
            sourcePricebookId: product.sourcePricebookId || null,
            sourcePricebookName: product.sourcePricebook || (isService ? 'Service' : ''),
            priceBadgeClass: this.getPriceBadgeClass(product.sourcePricebookType),
            priceBadgeLabel: this.getPriceBadgeLabel(product.sourcePricebookType),
            hasPriceSource: !!product.sourcePricebookType,
            managerDiscountUpTo: product.managerDiscountUpTo,
            vpDiscountUpTo: product.vpDiscountUpTo,
            ceoDiscountUpTo: product.ceoDiscountUpTo,
            installationCostPercent: product.installationCostPercent,
            insuranceCostPercent: product.insuranceCostPercent,
            transportCostPercent: product.transportCostPercent,
            promotionalCostPercent: product.promotionalCostPercent,
            trainingCostPercent: product.trainingCostPercent,
            warrantyCostPercent: product.warrantyCostPercent,
            discountDisplay: this.buildDiscountDisplay(product),
            discountTooltip: this.buildDiscountTooltip(product),
            totalCostPercentDisplay: this.buildTotalCostDisplay(product),
            costBreakdownTooltip: this.buildCostTooltip(product),
            discountInputClass: 'discount-input'
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
            if (item.rowId !== rowId) return item;
            const updated = { ...item };

            if (field === 'quantity') {
                updated.quantity = parseFloat(value) || 0;
            } else if (field === 'unitPrice') {
                const raw = parseFloat(value) || 0;
                // Sales Price floor: non-service lines cannot go below Price list5.
                // Users must use Discount to lower the effective price so approval
                // is engaged. Service lines have no floor.
                if (!updated.isServiceItem && raw < updated.listPrice) {
                    this.showError(
                        'Sales Price below standard',
                        'Sales Price cannot be below the standard list price (' +
                        this.formatCurrency(updated.listPrice) + '). Use Discount instead.'
                    );
                    // Snap back to the floor so server-side DML never rejects the save.
                    updated.unitPrice = updated.listPrice;
                } else {
                    updated.unitPrice = raw;
                }
            } else if (field === 'discount') {
                const d = parseFloat(value) || 0;
                updated.discount = d;
                const mgrCap = updated.managerDiscountUpTo;
                if (mgrCap != null && d > mgrCap) {
                    this.showToastWarn(
                        'Discount exceeds Manager limit',
                        `${updated.productName}: ${d}% is above Manager Discount Up To (${mgrCap}%). Higher-level approval will be required.`
                    );
                }
                updated.discountInputClass = this.getDiscountInputClass(d, mgrCap);
            } else if (field === 'taxPercent') {
                // Only service lines allow tax editing. Non-service tax is
                // server-stamped from Product2.Tax__c.
                if (updated.isServiceItem) {
                    updated.taxPercent = parseFloat(value) || 0;
                    updated.taxPercentDisplay = updated.taxPercent + '%';
                }
            }

            const base = updated.unitPrice * updated.quantity;
            const discountAmt = base * (updated.discount / 100);
            const afterDiscount = base - discountAmt;
            const taxAmt = afterDiscount * ((updated.taxPercent || 0) / 100);
            updated.lineTotal = afterDiscount + taxAmt;

            // Recompute price status from the standard-price comparison.
            // Preserves an already-Approved line so approvers' decisions are
            // not silently undone by a downstream edit.
            if (updated.priceStatus !== 'Approved') {
                const live = this.computePriceStatus(
                    updated.unitPrice, updated.discount, updated.listPrice, updated.isServiceItem
                );
                updated.priceStatus = live;
                updated.priceStatusBadgeClass = this.getPriceStatusBadgeClass(live);
                updated.isApprovalRequired = live === 'Approval Required';
            }

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
            // Service lines can carry UnitPrice = 0 (user has yet to enter it
            // at add-time but must enter before save).
            if (!item.isServiceItem && (!item.unitPrice || item.unitPrice <= 0)) {
                errors.push(`Sales Price for "${item.productName}" is not set.`);
            }
            if (item.isServiceItem && (item.unitPrice == null || item.unitPrice < 0)) {
                errors.push(`Sales Price for service item "${item.productName}" must be >= 0.`);
            }
            // Non-service floor safety net (trigger also enforces on server).
            if (!item.isServiceItem && item.listPrice != null && item.unitPrice < item.listPrice) {
                errors.push(
                    `Sales Price for "${item.productName}" cannot be below the standard list price.`
                );
            }
        }

        return errors;
    }

    // ===== PRICE STATUS =====

    // Mirrors PricebookTierService.computePriceStatus on the server.
    // Service lines are always 'Not Required' regardless of discount.
    // Non-service lines compare final unit price against Price list5 list
    // price (listPrice): below -> Approval Required, otherwise Not Required.
    computePriceStatus(unitPrice, discount, listPrice, isServiceItem) {
        if (isServiceItem) return 'Not Required';
        if (listPrice == null) return 'Not Required';
        const up = unitPrice == null ? 0 : unitPrice;
        const d = discount == null ? 0 : discount;
        const finalPrice = up * (1 - d / 100);
        return finalPrice < listPrice ? 'Approval Required' : 'Not Required';
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
            case 'Price list5': return base + ' price-source-standard';
            case 'Price list4': return base + ' price-source-tier4';
            case 'Price list3': return base + ' price-source-tier3';
            case 'Price list2': return base + ' price-source-tier2';
            case 'Price list1': return base + ' price-source-tier1';
            case 'Service':    return base + ' price-source-service';
            default:           return base + ' price-source-standard';
        }
    }

    getPriceBadgeLabel(pricebookType) {
        if (!pricebookType) return '';
        switch (pricebookType) {
            case 'Price list5': return 'Tier 5';
            case 'Price list4': return 'Tier 4';
            case 'Price list3': return 'Tier 3';
            case 'Price list2': return 'Tier 2';
            case 'Price list1': return 'Tier 1';
            case 'Service':    return 'Service';
            default:           return pricebookType;
        }
    }

    // ===== DISCOUNT + COST DISPLAY HELPERS =====

    buildDiscountDisplay(r) {
        const mgr = r.managerDiscountUpTo;
        const vp = r.vpDiscountUpTo;
        const ceo = r.ceoDiscountUpTo;
        if (mgr == null && vp == null && ceo == null) return '-';
        const fmt = v => (v == null ? '-' : v + '%');
        return `${fmt(mgr)} / ${fmt(vp)} / ${fmt(ceo)}`;
    }

    buildDiscountTooltip(r) {
        const mgr = r.managerDiscountUpTo;
        const vp = r.vpDiscountUpTo;
        const ceo = r.ceoDiscountUpTo;
        const fmt = v => (v == null ? 'N/A' : v + '%');
        return `Manager: ${fmt(mgr)}\nVP Sales: ${fmt(vp)}\nCEO Sales: ${fmt(ceo)}`;
    }

    buildTotalCostDisplay(r) {
        const total = (r.installationCostPercent || 0) + (r.insuranceCostPercent || 0) +
                      (r.transportCostPercent || 0) + (r.promotionalCostPercent || 0) +
                      (r.trainingCostPercent || 0) + (r.warrantyCostPercent || 0);
        if (total === 0) return '-';
        return total.toFixed(2) + '%';
    }

    buildCostTooltip(r) {
        const fmt = (label, v) => `${label}: ${v == null ? 0 : v}%`;
        return [
            fmt('Installation', r.installationCostPercent),
            fmt('Training', r.trainingCostPercent),
            fmt('Warranty', r.warrantyCostPercent),
            fmt('Insurance', r.insuranceCostPercent),
            fmt('Transport', r.transportCostPercent),
            fmt('Promotional', r.promotionalCostPercent)
        ].join('\n');
    }

    getDiscountInputClass(discount, mgrCap) {
        const d = discount == null ? 0 : discount;
        if (mgrCap != null && d > mgrCap) return 'discount-input discount-over-cap';
        return 'discount-input';
    }

    showToastWarn(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'warning' }));
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