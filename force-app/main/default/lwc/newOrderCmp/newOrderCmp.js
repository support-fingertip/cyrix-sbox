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
import getProductPricingPreview from '@salesforce/apex/QuoteBuilderController.getProductPricingPreview';

let rowCounter = 0;
let ptCounter = 0;

const STEP_LABELS = [
    'Order info', 'Addresses', 'Products', 'Payment', 'Notes', 'Review'
];
const TOTAL_STEPS = STEP_LABELS.length;

export default class NewOrderCmp extends NavigationMixin(LightningElement) {
    @api recordId;
    @api fromVisitPlan = false;

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
    carrySubVertical = null;
    carryShippingMode = null;
    carryDelivery = null;
    carryContractFrom = null;
    carryContractEnd = null;

    // Wizard state
    currentStep = 1;
    sameAsBilling = false;

    // ===== PICKLIST OPTIONS =====

    // Product Type filter (not Product Category). Values mirror the
    // Product_Type__c global value set on Product2.
    get categoryOptions() {
        return [
            { label: 'All Product Types', value: '' },
            { label: 'Equipment', value: 'Equipment' },
            { label: 'Spare', value: 'Spare' },
            { label: 'Accessories', value: 'Accessories' },
            { label: 'Consumables', value: 'Consumables' }
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
    get defaultSubVertical() {
        return this.isEditMode ? undefined : (this.carrySubVertical || undefined);
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

    // ===== WIZARD =====

    get currentStepLabel() {
        return STEP_LABELS[this.currentStep - 1] || '';
    }
    get progressPercent() {
        return Math.round(((this.currentStep - 1) / (TOTAL_STEPS - 1)) * 100);
    }
    get progressFillStyle() {
        return `width: ${this.progressPercent}%;`;
    }
    get isFirstStep() { return this.currentStep === 1; }
    get isLastStep() { return this.currentStep === TOTAL_STEPS; }

    get stepList() {
        return STEP_LABELS.map((label, idx) => {
            const num = idx + 1;
            let cssClass = 'qw-step';
            if (num === this.currentStep) cssClass += ' active';
            else if (num < this.currentStep) cssClass += ' done';
            return { num, label, cssClass };
        });
    }

    get step1Class() { return this.stepClass(1); }
    get step2Class() { return this.stepClass(2); }
    get step3Class() { return this.stepClass(3); }
    get step4Class() { return this.stepClass(4); }
    get step5Class() { return this.stepClass(5); }
    get step6Class() { return this.stepClass(6); }
    stepClass(n) {
        return n === this.currentStep ? 'qw-step-content active' : 'qw-step-content';
    }

    handleStepNext() {
        if (this.currentStep >= TOTAL_STEPS) return;
        const blocker = this.validateCurrentStep();
        if (blocker) {
            this.showError('Cannot continue', blocker);
            return;
        }
        this.currentStep += 1;
        this.scrollShellTop();
    }
    handleStepBack() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
            this.scrollShellTop();
        }
    }
    handleStepJump(event) {
        const target = parseInt(event.currentTarget.dataset.step, 10);
        if (!target || target === this.currentStep) return;
        if (target < 1 || target > TOTAL_STEPS) return;
        this.currentStep = target;
        this.scrollShellTop();
    }
    validateCurrentStep() {
        if (this.currentStep === 1 && !this.isEditMode && !this.sourceQuoteId) {
            return 'Pick a source Quote before continuing.';
        }
        if (this.currentStep === 3 && this.lineItems.length === 0) {
            return 'Add at least one product before continuing.';
        }
        if (this.currentStep === 4 && this.paymentTerms.length > 0 && this.totalPercentage !== 100) {
            return `Payment terms must total 100% (currently ${this.totalPercentage}%).`;
        }
        return null;
    }
    scrollShellTop() {
        try {
            const shell = this.template.querySelector('.qw-shell');
            if (shell && shell.scrollIntoView) {
                shell.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        } catch (e) { /* ignore */ }
    }

    handleSameAsBillingChange(event) {
        this.sameAsBilling = !!event.target.checked;
        if (this.sameAsBilling) {
            this.shippingAddress = { ...this.billingAddress };
        }
    }

    // ===== REVIEW STEP DISPLAY =====

    get accountNameDisplay() { return this.accountName || '—'; }
    get businessVerticalDisplay() { return this.carryBusinessVertical || '—'; }
    get subVerticalDisplay() { return this.carrySubVertical || '—'; }
    get billingSummary() { return this.formatAddress(this.billingAddress); }
    get shippingSummary() { return this.formatAddress(this.shippingAddress); }
    formatAddress(a) {
        if (!a) return '—';
        const parts = [a.street, a.city, a.state, a.postalCode].filter(Boolean);
        return parts.length ? parts.join(', ') : '—';
    }

    // ===== PAYMENT TOTAL STRIP =====

    get paymentTotalClass() {
        return this.totalPercentage === 100 ? 'qw-term-total ok' : 'qw-term-total err';
    }
    get paymentTotalText() {
        return this.totalPercentage === 100 ? 'Ready to proceed' : 'Must equal 100%';
    }

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

    get grandTotal() {
        return this.subtotal - this.totalDiscount + this.totalTax;
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
        this.carrySubVertical = data.subVertical;
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
            this.lineItems = data.lineItems.map(
                (item, index) => this.buildRowFromServerItem(item, index)
            );
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
            this.lineItems = data.lineItems.map(
                (item, index) => this.buildRowFromServerItem(item, index)
            );
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

    // Shared row builder for grid items sourced from the server (edit-mode
    // load and the source-Quote carry path). Status is read from the
    // server payload (or 'Not Required' for service items); the live
    // preview re-evaluates on the first edit.
    buildRowFromServerItem(item, index) {
        rowCounter++;
        const disc = item.discount || 0;
        const isService = item.isServiceItem === true;
        const base = (item.unitPrice || 0) * (item.quantity || 0);
        const discountedBase = base - (base * (disc / 100));
        const taxOnAfterDisc = discountedBase * ((item.taxPercent || 0) / 100);

        const VALID = ['Not Required', 'Approval Required', 'Approved'];
        let priceStatus;
        if (isService) priceStatus = 'Not Required';
        else if (VALID.includes(item.priceStatus)) priceStatus = item.priceStatus;
        else priceStatus = 'Not Required';

        return {
            rowId: 'row-' + rowCounter,
            rowNumber: index + 1,
            productId: item.productId,
            pricebookEntryId: item.pricebookEntryId,
            productName: item.productName,
            productInitial: this.getProductInitial(item.productName),
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
            qwStatusClass: this.getQwStatusClass(priceStatus),
            sourcePricebookId: item.sourcePricebookId || null,
            sourcePricebookName: item.sourcePricebookName || '',
            priceBadgeClass: this.getPriceBadgeClass(item.sourcePricebookName),
            priceBadgeLabel: this.getPriceBadgeLabel(item.sourcePricebookName),
            hasPriceSource: !!item.sourcePricebookName,
            lineTotal: discountedBase + taxOnAfterDisc
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
        if (this.sameAsBilling) {
            this.shippingAddress = { ...this.billingAddress };
        }
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
        // lightning-record-picker dispatches change with event.detail.recordId.
        // Older lightning-input-field lookups returned event.detail.value as
        // a 1-element array — keep that shape working too in case the
        // control gets swapped back.
        const d = event && event.detail ? event.detail : {};
        const newQuoteId = d.recordId
            || (Array.isArray(d.value) && d.value.length ? d.value[0] : null)
            || (typeof d.value === 'string' ? d.value : null)
            || null;
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
        this.carrySubVertical = null;
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

        if (!this.sourceQuoteId && !(event.detail.fields && event.detail.fields.QuoteId)) {
            this.showError(
                'Quote required',
                'Select a Quote before saving the order. Orders must be created from a quote.'
            );
            return;
        }

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
                unitPrice: item.unitPrice,
                discount: item.discount || 0,
                taxPercent: item.taxPercent || 0
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

    handleSearchTermChange(event) {
        this.searchTerm = event.detail ? event.detail.value : event.target.value;
    }
    handleCategoryFilterChange(event) { this.categoryFilter = event.detail.value; }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            event.stopPropagation();
            this.handleSearch();
        }
    }

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
        const priceStatus = 'Not Required';

        const newItem = {
            rowId: 'row-' + rowCounter,
            rowNumber: this.lineItems.length + 1,
            productId: product.productId,
            pricebookEntryId: product.pricebookEntryId,
            productName: product.productName,
            productInitial: this.getProductInitial(product.productName),
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
            qwStatusClass: this.getQwStatusClass(priceStatus),
            sourcePricebookId: product.sourcePricebookId || null,
            sourcePricebookName: product.sourcePricebook || (isService ? 'Service' : ''),
            priceBadgeClass: this.getPriceBadgeClass(product.sourcePricebookType),
            priceBadgeLabel: this.getPriceBadgeLabel(product.sourcePricebookType),
            hasPriceSource: !!product.sourcePricebookType,
            lineTotal: base + tax
        };

        this.lineItems = [...this.lineItems, newItem];

        // Run the discount/ceiling evaluator on the freshly added line so
        // the badge + tier reflect the current state without waiting for
        // the rep's first discount edit.
        if (!isService) this.refreshPricingPreview(newItem.rowId);

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

        const refreshTier = field === 'discount' || field === 'unitPrice' || field === 'quantity';

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
            } else if (field === 'discount') {
                let d = parseFloat(value) || 0;
                if (d < 0) d = 0;
                if (d > 100) d = 100;
                updated.discount = d;
            }

            const base = (updated.unitPrice || 0) * (updated.quantity || 0);
            const discAmt = base * ((updated.discount || 0) / 100);
            const afterDisc = base - discAmt;
            const taxAmt = afterDisc * ((updated.taxPercent || 0) / 100);
            updated.lineTotal = afterDisc + taxAmt;

            return updated;
        });

        // Server-side evaluator owns the price-status / mapped-tier
        // decision. Ping it on every meaningful change so the UI badge
        // stays consistent with the trigger's save-time stamp.
        if (refreshTier) this.refreshPricingPreview(rowId);
    }

    // Ask the server to run the discount-vs-Discount__c algorithm and
    // update the line with the resolved tier, the new UnitPrice (re-fetched
    // from that tier's PricebookEntry), and the resulting Price_Status.
    // Already-Approved lines are skipped so an approver's decision isn't
    // silently undone by a later edit.
    async refreshPricingPreview(rowId) {
        const item = this.lineItems.find(it => it.rowId === rowId);
        if (!item || item.priceStatus === 'Approved') return;
        if (!item.productId) return;

        try {
            const preview = await getProductPricingPreview({
                productId: item.productId,
                unitPrice: item.unitPrice,
                discount: item.discount || 0,
                quantity: item.quantity || 1
            });

            const resolvedPb = preview.resolvedTier || '';
            this.lineItems = this.lineItems.map(it => {
                if (it.rowId !== rowId) return it;
                const updated = { ...it };
                updated.priceStatus = preview.priceStatus || updated.priceStatus;
                updated.priceStatusBadgeClass = this.getPriceStatusBadgeClass(updated.priceStatus);
                updated.qwStatusClass = this.getQwStatusClass(updated.priceStatus);
                if (preview.resolvedPricebookId) updated.sourcePricebookId = preview.resolvedPricebookId;
                if (resolvedPb) {
                    updated.sourcePricebookName = resolvedPb;
                    updated.priceBadgeClass = this.getPriceBadgeClass(resolvedPb);
                    updated.priceBadgeLabel = this.getPriceBadgeLabel(resolvedPb);
                    updated.hasPriceSource = true;
                }
                if (preview.resolvedPricebookEntryId) {
                    updated.pricebookEntryId = preview.resolvedPricebookEntryId;
                }
                if (preview.ceilingTierDiscount != null) {
                    updated.maxDiscount = preview.ceilingTierDiscount;
                    updated.maxDiscountDisplay = this.formatMaxDiscount(preview.ceilingTierDiscount);
                    updated.hasMaxDiscount = true;
                }
                // UnitPrice is intentionally NOT updated from the preview;
                // escalation only changes the approval path, not the
                // displayed Sales Price.
                return updated;
            });
        } catch (error) {
            console.warn('Pricing preview unavailable:', error && error.body ? error.body.message : error);
        }
    }

    formatMaxDiscount(value) {
        if (value == null) return '';
        const n = Number(value);
        if (!isFinite(n)) return '';
        return (n % 1 === 0 ? n.toFixed(0) : n.toFixed(2)) + '%';
    }

    getPriceStatusBadgeClass(status) {
        const base = 'slds-badge';
        switch (status) {
            case 'Approval Required': return base + ' slds-theme_error';
            case 'Approved':          return base + ' slds-theme_success';
            case 'Not Required':
            default:                  return base + ' slds-theme_shade';
        }
    }

    // Wizard-style status pill (qw-status-badge variants). Approved /
    // Not Required render as the green default; Approval Required
    // surfaces the amber pending pill so the rep notices.
    getQwStatusClass(status) {
        switch (status) {
            case 'Approval Required': return 'qw-status-badge pending';
            case 'Approved':
            case 'Not Required':
            default:                  return 'qw-status-badge';
        }
    }

    // First-letter thumbnail label for the line-item card head.
    getProductInitial(name) {
        if (!name || typeof name !== 'string') return '?';
        const ch = name.trim().charAt(0);
        return ch ? ch.toUpperCase() : '?';
    }

    // ===== PRICING BADGE HELPERS =====

    getPriceBadgeClass(pricebookType) {
        const base = 'price-source-badge';
        if (!pricebookType) return base + ' price-source-standard';
        switch (this.normaliseTier(pricebookType)) {
            case 'Standard':     return base + ' price-source-standard';
            case 'Price List 5': return base + ' price-source-standard';
            case 'Price List 4': return base + ' price-source-tier4';
            case 'Price List 3': return base + ' price-source-tier3';
            case 'Price List 2': return base + ' price-source-tier2';
            case 'Price List 1': return base + ' price-source-tier1';
            case 'Service':      return base + ' price-source-service';
            default:             return base + ' price-source-standard';
        }
    }

    getPriceBadgeLabel(pricebookType) {
        if (!pricebookType) return '';
        switch (this.normaliseTier(pricebookType)) {
            case 'Standard':     return 'Standard';
            case 'Price List 5': return 'Tier 5';
            case 'Price List 4': return 'Tier 4';
            case 'Price List 3': return 'Tier 3';
            case 'Price List 2': return 'Tier 2';
            case 'Price List 1': return 'Tier 1';
            case 'Service':      return 'Service';
            default:             return pricebookType;
        }
    }

    // Older saves stored the tier name with various casings ('Price list4',
    // 'Price list 4', etc.). Normalise to the canonical 'Price List N'
    // form so the badge maps stay clean.
    normaliseTier(name) {
        if (!name) return '';
        const m = String(name).trim().match(/^price\s*list\s*([1-5])$/i);
        if (m) return 'Price List ' + m[1];
        if (/^standard$/i.test(name)) return 'Standard';
        if (/^service$/i.test(name)) return 'Service';
        return name;
    }

    // ===== CANCEL =====

    handleVisitPlanCancel() {
        // Launched from the Visit Plan order session. Notify the parent
        // (orderSessionPage) so it can switch back to the order list.
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());

        setTimeout(() => {
            const target = this.resolveCancelTarget();
            if (target) {
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: target.recordId,
                        objectApiName: target.objectApiName,
                        actionName: 'view'
                    }
                });
            } else {
                // No parent record to return to — send the user to the
                // Order home tab instead of a broken record URL.
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: 'Order',
                        actionName: 'home'
                    }
                });
            }
        }, 300);
    }

    resolveCancelTarget() {
        if (this.isEditMode && this.editRecordId) {
            return { recordId: this.editRecordId, objectApiName: 'Order' };
        }
        const id = this.recordId;
        if (!id || typeof id !== 'string' || id.length < 3) return null;
        const prefix = id.substring(0, 3);
        if (prefix === '006') return { recordId: id, objectApiName: 'Opportunity' };
        if (prefix === '001') return { recordId: id, objectApiName: 'Account' };
        if (prefix === '0Q0') return { recordId: id, objectApiName: 'Quote' };
        if (prefix === '801') return { recordId: id, objectApiName: 'Order' };
        return null;
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