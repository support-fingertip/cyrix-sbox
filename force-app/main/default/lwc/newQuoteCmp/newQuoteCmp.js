import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getOpportunityContext from '@salesforce/apex/QuoteBuilderController.getOpportunityContext';
import getQuoteForEdit from '@salesforce/apex/QuoteBuilderController.getQuoteForEdit';
import searchProductsWithBestPrice from '@salesforce/apex/QuoteBuilderController.searchProductsWithBestPrice';
import getProductPricingPreview from '@salesforce/apex/QuoteBuilderController.getProductPricingPreview';
import saveQuoteLineItems from '@salesforce/apex/QuoteBuilderController.saveQuoteLineItems';
import updateQuoteLineItems from '@salesforce/apex/QuoteBuilderController.updateQuoteLineItems';
import savePaymentTerms from '@salesforce/apex/QuoteBuilderController.savePaymentTerms';

let rowCounter = 0;
let ptCounter = 0;

const STEP_LABELS = [
    'Quote info', 'Addresses', 'Products', 'Payment', 'Notes', 'Review'
];
const TOTAL_STEPS = STEP_LABELS.length;

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
    // Mapped from Opportunity.Buisness_Vertical__c / .Sub_Vertical__c.
    // Rendered as plain readonly text on the form so updates propagate
    // (lightning-input-field reads `value` only at mount and caches
    // via LDS, which silently swallows mid-form Opportunity changes).
    // handleFormSubmit pulls these into the field payload before save.
    businessVertical = null;
    subVertical = null;

    // Default values for new quote (is_Active defaults to true so fresh quotes
    // are marked as the active one for the opportunity).
    defaultValues = { is_Active__c: true };

    // Address objects for custom address input
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

    // Contract period dates (tracked locally for cross-field validation)
    contractFromDate = null;
    contractEndDate = null;

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
    get isSaveDisabled() {
        if (this.isSaving || this.lineItems.length === 0) return true;
        if (this.paymentTerms.length > 0 && this.totalPercentage !== 100) return true;
        if (this.isContractDateInvalid) return true;
        return false;
    }
    get pageTitle() { return this.isEditMode ? 'Edit Quote' : 'Create Quote'; }
    get quoteName() { return this.isEditMode ? undefined : 'Auto'; }
    get saveButtonLabel() { return this.isSaving ? 'Saving...' : (this.isEditMode ? 'Update Quote' : 'Save Quote'); }
    get hasPaymentTerms() { return this.paymentTerms.length > 0; }
    get paymentTermCount() { return this.paymentTerms.length; }
    get totalPercentage() {
        return this.paymentTerms.reduce((sum, t) => sum + (parseFloat(t.percentage) || 0), 0);
    }
    get percentageOverflow() { return this.totalPercentage > 100; }
    get percentageUnderflow() { return this.paymentTerms.length > 0 && this.totalPercentage < 100; }
    get totalPercentageClass() {
        return (this.paymentTerms.length > 0 && this.totalPercentage !== 100)
            ? 'slds-text-color_error'
            : 'slds-text-color_success';
    }
    get isContractDateInvalid() {
        if (!this.contractFromDate || !this.contractEndDate) return false;
        return new Date(this.contractEndDate) <= new Date(this.contractFromDate);
    }
    // In edit mode, return undefined so an empty defaultValues object can't
    // interfere with LDS auto-loading the saved Quote address subfields.
    get formDefaultValues() { return this.isEditMode ? undefined : this.defaultValues; }
    // Force is_Active__c to be checked on new quote creation. In edit mode,
    // returning undefined lets lightning-input-field fall back to the saved
    // record value.
    get defaultIsActive() { return this.isEditMode ? undefined : true; }
    // Prefill Business Vertical from the parent Opportunity on new quotes.
    // In edit mode fall through to the saved Quote value so we don't
    // overwrite the record with a blank.

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

    // Returns a blocker message if the current step isn't ready to leave,
    // or null when it's safe to advance. Step 6 has no Continue (Submit
    // takes over) so we don't validate it here.
    validateCurrentStep() {
        if (this.currentStep === 1 && this.isContractDateInvalid) {
            return 'Contract End Date must be greater than From Date.';
        }
        if (this.currentStep === 2
                && (!this.billingAddress || !this.billingAddress.state)) {
            return 'Bill To state is required — it drives the auto-generated quote name.';
        }
        if (this.currentStep === 3 && this.lineItems.length === 0) {
            return 'Add at least one product before continuing.';
        }
        if (this.currentStep === 4 && this.paymentTerms.length > 0 && this.totalPercentage !== 100) {
            return `Payment terms must total 100% (currently ${this.totalPercentage}%).`;
        }
        return null;
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
        // Free navigation — clicking any step in the stepper or any
        // Edit chip on the Review step jumps directly. The form's own
        // submit-time validation still gates the final save, so we
        // don't need to forward-lock the wizard.
        this.currentStep = target;
        this.scrollShellTop();
    }
    scrollShellTop() {
        // Scroll the wizard shell into view so the user lands at the top
        // of the new step on long mobile pages.
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
    get businessVerticalDisplay() { return this.businessVertical || '—'; }
    get subVerticalDisplay() { return this.subVertical || '—'; }
    // Contract dates are only meaningful for maintenance contracts —
    // AMC and CAMC sub-verticals. Hide them on every other quote so
    // the rep doesn't see fields they aren't expected to fill.
    get showContractDates() {
        const sv = (this.subVertical || '').trim();
        return sv === 'AMC' || sv === 'CAMC';
    }
    // Number of Preventive Maintenance visits is an AMC-only commitment;
    // CAMC and other sub-verticals don't need it on the form.
    get showPreventiveMaintenanceCount() {
        const sv = (this.subVertical || '').trim();
        return sv === 'AMC';
    }
    get contractDateDisplay() {
        if (!this.contractFromDate && !this.contractEndDate) return '—';
        return `${this.contractFromDate || '—'} → ${this.contractEndDate || '—'}`;
    }
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
            this.businessVertical = data.vertical || null;
            this.subVertical = data.subVertical || null;

            // === AUTO-POPULATE BILL TO + SHIP TO FROM ACCOUNT ===
            // Bill To always comes from the account billing address.
            // Ship To prefers the account's shipping address; if the
            // account doesn't have one, fall back to billing so the
            // ship-to card never starts blank.
            if (!this.isEditMode && this.accountId) {
                this.billingAddress = {
                    name: data.billingName || '',
                    street: data.billingStreet || '',
                    city: data.billingCity || '',
                    state: data.billingState || '',
                    postalCode: data.billingPostalCode || '',
                    country: data.billingCountry || 'IN'
                };
                const hasShipping = data.shippingStreet || data.shippingCity
                    || data.shippingState || data.shippingPostalCode;
                this.shippingAddress = hasShipping
                    ? {
                        name: data.shippingName || data.billingName || '',
                        street: data.shippingStreet || '',
                        city: data.shippingCity || '',
                        state: data.shippingState || '',
                        postalCode: data.shippingPostalCode || '',
                        country: data.shippingCountry || 'IN'
                    }
                    : { ...this.billingAddress };
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

            // === PREFILL LINE ITEMS FROM OPPORTUNITY PRODUCTS ===
            // When the parent Opportunity has products attached, seed the
            // new-quote grid with them so the rep doesn't re-enter each SKU.
            // Only runs on fresh quotes and only when the grid is still empty
            // — never clobber anything the user has already added.
            if (!this.isEditMode
                && this.lineItems.length === 0
                && Array.isArray(data.opportunityLineItems)
                && data.opportunityLineItems.length > 0) {
                this.lineItems = data.opportunityLineItems.map(
                    (item, index) => this.buildRowFromServerItem(item, index)
                );
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
            this.businessVertical = data.vertical || null;
            this.subVertical = data.subVertical || null;

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

            if (data.lineItems && data.lineItems.length > 0) {
                this.lineItems = data.lineItems.map((item, index) => this.buildRowFromServerItem(item, index));
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
        // When the user has opted in to "same as billing", keep shipping
        // mirrored as the billing fields are edited.
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

    // ===== CONTRACT DATE HANDLERS =====

    handleContractFromDateChange(event) {
        this.contractFromDate = event.detail ? event.detail.value : event.target.value;
    }

    handleContractEndDateChange(event) {
        this.contractEndDate = event.detail ? event.detail.value : event.target.value;
    }

    // Refetch verticals + default payment terms when the rep picks a
    // different Opportunity on the form. Replaces the auto-loaded
    // payment-terms list on new quotes; in edit mode we leave existing
    // payment terms alone so a manual override isn't wiped.
    async handleOpportunityChange(event) {
        // lightning-record-picker dispatches change with recordId in
        // event.detail.recordId. Fall through to the older shapes too
        // (lightning-input-field / native) so this handler stays compatible
        // if the on-form Opportunity control gets swapped back.
        const d = event && event.detail ? event.detail : {};
        const newOppId = d.recordId || d.value || (event.target && event.target.value) || null;
        // Track the selection so handleFormSubmit can inject it as
        // fields.OpportunityId — the picker isn't an input-field, so the
        // form's submit payload doesn't pick it up automatically.
        this.defaultOpportunityId = newOppId || null;
        if (!newOppId) {
            // Selection cleared — wipe verticals so they don't display a
            // stale value. Payment terms are left as-is so the rep doesn't
            // lose anything they may have customised.
            this.businessVertical = null;
            this.subVertical = null;
            return;
        }
        try {
            const data = await getOpportunityContext({ opportunityId: newOppId });
            if (!data) return;
            this.businessVertical = data.vertical || null;
            this.subVertical = data.subVertical || null;
            // Auto-fill billing + shipping address from the Opportunity's
            // account when the rep hasn't typed anything yet, mirroring the
            // launched-from-Opportunity flow. Ship To uses the account's
            // shipping address and falls back to billing when shipping
            // isn't on the account.
            if (data.accountId) {
                this.accountId = data.accountId;
                this.accountName = data.accountName || '';
                if (!this.billingAddress.street && !this.billingAddress.city) {
                    this.billingAddress = {
                        name: data.billingName || '',
                        street: data.billingStreet || '',
                        city: data.billingCity || '',
                        state: data.billingState || '',
                        postalCode: data.billingPostalCode || '',
                        country: data.billingCountry || 'IN'
                    };
                }
                if (!this.shippingAddress.street && !this.shippingAddress.city) {
                    const hasShipping = data.shippingStreet || data.shippingCity
                        || data.shippingState || data.shippingPostalCode;
                    this.shippingAddress = hasShipping
                        ? {
                            name: data.shippingName || data.billingName || '',
                            street: data.shippingStreet || '',
                            city: data.shippingCity || '',
                            state: data.shippingState || '',
                            postalCode: data.shippingPostalCode || '',
                            country: data.shippingCountry || 'IN'
                        }
                        : { ...this.billingAddress };
                }
                if (this.sameAsBilling) {
                    this.shippingAddress = { ...this.billingAddress };
                }
            }
            // Replace the auto-loaded payment terms with whatever the new
            // Opportunity's vertical / sub-vertical pair maps to.
            if (Array.isArray(data.defaultPaymentTerms) && data.defaultPaymentTerms.length > 0) {
                this.paymentTerms = data.defaultPaymentTerms.map((t, idx) => {
                    ptCounter++;
                    return {
                        ptId: 'pt-' + ptCounter,
                        rowNumber: idx + 1,
                        paymentTerm: t.paymentTerm || '',
                        percentage: t.percentage || 0
                    };
                });
            }
        } catch (error) {
            // Silent — the rep can still finish the form; verticals just
            // won't auto-update for this opportunity.
        }
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

        // Billing state drives the auto-generated quote name, so block
        // save when it isn't filled — the trigger that names the quote
        // would addError on insert otherwise and the rep would see a
        // less specific server-side message.
        if (!this.billingAddress || !this.billingAddress.state) {
            this.showError('Billing state required',
                'Please fill the Bill To state before saving — it drives the quote name.');
            return;
        }

        const fields = event.detail.fields;

        // Payment terms (if any) must sum to exactly 100%.
        if (this.paymentTerms.length > 0 && this.totalPercentage !== 100) {
            this.showError(
                'Payment Terms Invalid',
                'Total percentage of Payment Terms must equal 100% to save the quote.'
            );
            return;
        }

        // Contract Period End Date must be after From Date when both provided.
        const fromDate = fields.Contract_Period_From_Date__c;
        const endDate = fields.Contract_Period_End_Date__c;
        if (fromDate && endDate && new Date(endDate) <= new Date(fromDate)) {
            this.showError(
                'Invalid Contract Period',
                'Contract Period End Date must be greater than Contract Period From Date.'
            );
            return;
        }

        // Set placeholder Name (trigger auto-generates the actual quote name)
        if (!this.isEditMode) {
            fields.Name = 'Auto';
        }

        // Inject Pricebook2Id
        fields.Pricebook2Id = this.pricebookId;

        // Inject OpportunityId from the lightning-record-picker — that
        // control isn't a lightning-input-field, so the form's submit
        // payload doesn't include it automatically.
        if (this.defaultOpportunityId) {
            fields.OpportunityId = this.defaultOpportunityId;
        }

        // Inject verticals — these are rendered as readonly displays
        // (not lightning-input-fields) so they aren't in event.detail.fields
        // by default. Pull from tracked state which mirrors the parent
        // Opportunity (and re-fetches when the rep changes Opportunity
        // mid-form).
        if (this.businessVertical) {
            fields.Business_Vertical__c = this.businessVertical;
        }
        if (this.subVertical) {
            fields.Sub_Vertical__c = this.subVertical;
        }

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
                taxPercent: item.taxPercent,
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

    handleSearchTermChange(event) {
        this.searchTerm = event.detail ? event.detail.value : event.target.value;
        // Clearing the search input should also clear the previously-returned
        // results so the user doesn't see stale products after wiping the term.
        if (!this.searchTerm || !this.searchTerm.trim()) {
            this.searchResults = [];
            this.showSearchResults = false;
        }
    }
    handleCategoryFilterChange(event) { this.categoryFilter = event.detail.value; }

    handleSearchKeydown(event) {
        if (event.key === 'Enter') {
            // Prevent Enter from submitting the outer lightning-record-edit-form
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
        // Extract the discount-tier PBE prices (PL4 -> PL1) from the
        // search result so computePriceStatus can iterate them without
        // a server round-trip.
        const tierPrices = Array.isArray(product.availablePrices)
            ? product.availablePrices.map(p => p.price).filter(v => v != null)
            : [];
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
            isApprovalRequired: priceStatus === 'Approval Required',
            lineTotal: (product.unitPrice || 0) * (1 + ((product.taxPercent || 0) / 100)),
            lineDescription: product.lineDescription || '',
            detailedDescription: product.detailedDescription || '',
            sourcePricebookId: product.sourcePricebookId || null,
            sourcePricebookName: product.sourcePricebook || (isService ? 'Service' : ''),
            priceBadgeClass: this.getPriceBadgeClass(product.sourcePricebookType),
            priceBadgeLabel: this.getPriceBadgeLabel(product.sourcePricebookType),
            hasPriceSource: !!product.sourcePricebookType,
            tierPrices: tierPrices
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

        const refreshTier = field === 'discount' || field === 'unitPrice' || field === 'quantity';

        this.lineItems = this.lineItems.map(item => {
            if (item.rowId !== rowId) return item;
            const updated = { ...item };

            if (field === 'quantity') {
                updated.quantity = parseFloat(value) || 0;
            } else if (field === 'unitPrice') {
                const raw = parseFloat(value) || 0;
                // For non-service lines, Sales Price can be raised above
                // list price but never dropped below it — discount is the
                // lever for going below the list. If the rep types a
                // value below list, snap back to list silently.
                if (!updated.isServiceItem) {
                    const lp = updated.listPrice == null ? 0 : updated.listPrice;
                    updated.unitPrice = raw < lp ? lp : raw;
                } else {
                    updated.unitPrice = raw;
                }
            } else if (field === 'discount') {
                updated.discount = parseFloat(value) || 0;
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

            // Recompute price status against the product's tier PBE
            // prices (PL4..PL1). Preserves an already-Approved line so
            // approvers' decisions aren't silently undone by a later edit.
            if (updated.priceStatus !== 'Approved') {
                const live = this.computePriceStatus(
                    updated.unitPrice,
                    updated.discount,
                    updated.listPrice,
                    updated.isServiceItem,
                    updated.taxPercent,
                    updated.tierPrices
                );
                updated.priceStatus = live;
                updated.priceStatusBadgeClass = this.getPriceStatusBadgeClass(live);
                updated.qwStatusClass = this.getQwStatusClass(live);
                updated.isApprovalRequired = live === 'Approval Required';
            }

            return updated;
        });

        if (refreshTier) this.refreshPricingPreview(rowId);
    }

    // Asks the server for the tightest-fitting tier based on the current
    // unit price and discount. The server answer is authoritative for the
    // tier badge + Price_Status — matches what the QLI trigger will stamp
    // on save. Skipped for service lines and for already-Approved lines.
    async refreshPricingPreview(rowId) {
        const item = this.lineItems.find(it => it.rowId === rowId);
        if (!item || item.isServiceItem || item.priceStatus === 'Approved') return;
        if (!item.productId || item.unitPrice == null) return;

        try {
            const preview = await getProductPricingPreview({
                productId: item.productId,
                unitPrice: item.unitPrice,
                discount: item.discount || 0,
                quantity: item.quantity || 1
            });

            // Apex returns resolvedTier = 'Standard' when the per-unit
            // final is above PL4 (no discount tier applies), else one
            // of 'Price list4'..'Price list1'. Fall back to 'Standard'
            // so the UI matches the save-time stamp on the org's
            // Standard Pricebook.
            const resolvedPb = preview.resolvedTier || 'Standard';
            this.lineItems = this.lineItems.map(it => {
                if (it.rowId !== rowId) return it;
                const updated = { ...it };
                updated.priceStatus = preview.priceStatus || updated.priceStatus;
                updated.priceStatusBadgeClass = this.getPriceStatusBadgeClass(updated.priceStatus);
                updated.qwStatusClass = this.getQwStatusClass(updated.priceStatus);
                updated.isApprovalRequired = updated.priceStatus === 'Approval Required';
                updated.sourcePricebookId = preview.resolvedPricebookId || updated.sourcePricebookId;
                updated.sourcePricebookName = resolvedPb;
                updated.priceBadgeClass = this.getPriceBadgeClass(resolvedPb);
                updated.priceBadgeLabel = this.getPriceBadgeLabel(resolvedPb);
                updated.hasPriceSource = !!resolvedPb;
                return updated;
            });
        } catch (error) {
            // Server rejects UnitPrice < Price list5 by throwing — the
            // client floor already caught that; any other rejection is
            // non-fatal for the live UI (the save trigger remains the
            // source of truth). Log quietly to the console.
            console.warn('Pricing preview unavailable:', error && error.body ? error.body.message : error);
        }
    }

    // ===== CANCEL =====

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
                // No parent record to return to (e.g. launched directly from
                // the app launcher). Land on the Quote home tab so the user
                // doesn't see a "page doesn't exist" dead end.
                this[NavigationMixin.Navigate]({
                    type: 'standard__objectPage',
                    attributes: {
                        objectApiName: 'Quote',
                        actionName: 'home'
                    }
                });
            }
        }, 300);
    }

    resolveCancelTarget() {
        if (this.isEditMode && this.editRecordId) {
            return { recordId: this.editRecordId, objectApiName: 'Quote' };
        }
        const id = this.recordId;
        if (!id || typeof id !== 'string' || id.length < 3) return null;
        const prefix = id.substring(0, 3);
        if (prefix === '006') return { recordId: id, objectApiName: 'Opportunity' };
        if (prefix === '001') return { recordId: id, objectApiName: 'Account' };
        if (prefix === '0Q0') return { recordId: id, objectApiName: 'Quote' };
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

    // Shared builder for grid rows sourced from the server — used by
    // edit-mode QLI loading and by the new-quote flow when prefilling
    // from the parent Opportunity's products.
    buildRowFromServerItem(item, index) {
        rowCounter++;
        const disc = item.discount || 0;
        const isService = item.isServiceItem === true;
        const base = (item.unitPrice || 0) * (item.quantity || 0);
        const discountAmt = base * (disc / 100);
        const afterDiscount = base - discountAmt;
        const taxAmt = afterDiscount * ((item.taxPercent || 0) / 100);

        // Server doesn't ship tier PBE prices on load — computePriceStatus
        // falls back to the listPrice comparison; the live preview will
        // refresh the status on the first edit.
        const tierPricesFromDb = [];
        const VALID_LINE_STATUSES = ['Not Required', 'Approval Required', 'Approved'];
        // Service items (Service_Item picklist = Yes) never require
        // approval — ignore any stale server value that says otherwise.
        let priceStatus;
        if (isService) {
            priceStatus = 'Not Required';
        } else if (VALID_LINE_STATUSES.includes(item.priceStatus)) {
            priceStatus = item.priceStatus;
        } else {
            priceStatus = this.computePriceStatus(
                item.unitPrice, disc, item.listPrice, isService,
                item.taxPercent, tierPricesFromDb
            );
        }

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
            isApprovalRequired: priceStatus === 'Approval Required',
            lineTotal: afterDiscount + taxAmt,
            lineDescription: item.lineDescription || '',
            detailedDescription: item.detailedDescription || '',
            sourcePricebookId: item.sourcePricebookId || null,
            sourcePricebookName: item.sourcePricebookName || '',
            tierPrices: tierPricesFromDb,
            priceBadgeClass: this.getPriceBadgeClass(item.sourcePricebookName),
            priceBadgeLabel: this.getPriceBadgeLabel(item.sourcePricebookName),
            hasPriceSource: !!item.sourcePricebookName
        };
    }

    // ===== PRICE STATUS =====

    // Client-side mirror of the server's Price_Status decision.
    //
    // Non-service logic:
    //   finalPrice = unitPrice
    //              - (discount% of unitPrice)
    //              - (tax% of unitPrice)
    //   Walk the product's existing discount-tier pricebooks (Price list4
    //   down to Price list1, excluding the Standard pricebook). If
    //   finalPrice is <= any of those tier list prices, return
    //   'Approval Required'. Otherwise compare to listPrice (the Standard
    //   / Price list5 anchor) as the last-resort fallback for products
    //   that don't have any tier pricebooks populated.
    //
    // Service lines (Product's Service_Item picklist = Yes) always return
    // 'Not Required' — the tier/list-price approval gate doesn't apply.
    computePriceStatus(unitPrice, discount, listPrice, isServiceItem, taxpercentage, tierPrices) {
        if (isServiceItem) return 'Not Required';

        const tax = taxpercentage == null ? 0 : taxpercentage;
        const up  = unitPrice == null ? 0 : unitPrice;
        const d   = discount == null ? 0 : discount;
        const taxprice = (up * tax) / 100;
        const finalPrice = up - ((d * up) / 100) - taxprice;

        // Iterate the product's tier PBE prices (PL4 -> PL1, already
        // excludes Standard). If any tier price is >= finalPrice, the
        // discount has dropped the line into that tier's band and the
        // status flips to Approval Required.
        if (Array.isArray(tierPrices)) {
            for (const tp of tierPrices) {
               
                if (tp != null && finalPrice <= tp) return 'Approval Required';
            }
            // No tier matched and tier data was actually supplied —
            // final price is above every discount tier; no approval.
            if (tierPrices.length > 0) return 'Not Required';
        }

        // Fallback for products with no tier PBEs configured.
        if (listPrice == null) return 'Not Required';
        return finalPrice <= listPrice ? 'Approval Required' : 'Not Required';
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

    // Wizard-style status pill (qw-status-badge variants).
    // Approved / Not Required render as the green default; Approval
    // Required surfaces the amber pending pill so the rep notices.
    getQwStatusClass(priceStatus) {
        switch (priceStatus) {
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
        switch (pricebookType) {
            case 'Standard':    return base + ' price-source-standard';
            case 'Price list 5': return base + ' price-source-standard';
            case 'Price list 4': return base + ' price-source-tier4';
            case 'Price list 3': return base + ' price-source-tier3';
            case 'Price list 2': return base + ' price-source-tier2';
            case 'Price list 1': return base + ' price-source-tier1';
            case 'Service':    return base + ' price-source-service';
            default:           return base + ' price-source-standard';
        }
    }

    getPriceBadgeLabel(pricebookType) {
        if (!pricebookType) return '';
        switch (pricebookType) {
            case 'Standard':    return 'Standard';
            case 'Price list 5': return 'Tier 5';
            case 'Price list 4': return 'Tier 4';
            case 'Price list 3': return 'Tier 3';
            case 'Price list 2': return 'Tier 2';
            case 'Price list 1': return 'Tier 1';
            case 'Service':    return 'Service';
            default:           return pricebookType;
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