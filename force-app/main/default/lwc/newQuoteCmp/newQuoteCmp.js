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
    get isSearchDisabled() { return !this.searchTerm || this.searchTerm.trim().length < 2; }
    get searchResultCountLabel() {
        const n = this.searchResults.length;
        return n === 1 ? '1 product found' : `${n} products found`;
    }
    get isSaveDisabled() {
        if (this.isSaving || this.lineItems.length === 0) return true;
        if (this.paymentTerms.length > 0 && this.totalPercentage !== 100) return true;
        if (this.isContractDateInvalid) return true;
        if (this.isContractFromDateMissing || this.isContractEndDateMissing) return true;
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
    // AMC / CAMC sub-verticals must carry both contract period dates.
    // We surface a per-field error and block the wizard until they're set.
    get isContractFromDateMissing() {
        return this.showContractDates && !this.contractFromDate;
    }
    get isContractEndDateMissing() {
        return this.showContractDates && !this.contractEndDate;
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
        if (this.currentStep === 1) {
            if (this.isContractFromDateMissing && this.isContractEndDateMissing) {
                return 'Contract Period From Date and End Date are required.';
            }
            if (this.isContractFromDateMissing) {
                return 'Contract Period From Date is required.';
            }
            if (this.isContractEndDateMissing) {
                return 'Contract Period End Date is required.';
            }
            if (this.isContractDateInvalid) {
                return 'Contract End Date must be greater than From Date.';
            }
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
            this.contractFromDate = data.contractFromDate || null;
            this.contractEndDate = data.contractEndDate || null;

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
            // Surface stage-restriction (and any other server-side block)
            // and clear the picker so the rep doesn't unknowingly continue
            // with an Opportunity the server has rejected.
            this.defaultOpportunityId = null;
            this.businessVertical = null;
            this.subVertical = null;
            this.showError('Cannot use this Opportunity', this.reduceErrors(error));
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

        // AMC / CAMC sub-verticals require both contract dates — they
        // anchor the maintenance window so saves without them aren't valid.
        if (this.showContractDates && (!fromDate || !endDate)) {
            const missing = [];
            if (!fromDate) missing.push('Contract Period From Date');
            if (!endDate) missing.push('Contract Period End Date');
            this.showError(
                'Contract dates required',
                `${missing.join(' and ')} ${missing.length === 1 ? 'is' : 'are'} required.`
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
        const detail = event.detail || {};
        // record-edit-form's onerror payload nests the field/page error
        // bag under detail.output — reduceErrors knows how to walk it
        // and yields friendlier multi-line messages than detail.message
        // (which is just the top-line summary).
        const message = this.reduceErrors({ body: detail })
            || detail.message
            || 'An error occurred while saving the quote.';
        this.showError('Save Failed', message);
        console.error('Form error:', JSON.stringify(detail));
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

    handleClearSearch() {
        this.searchTerm = '';
        this.categoryFilter = '';
        this.searchResults = [];
        this.showSearchResults = false;
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

            const addedKeys = new Set(this.lineItems.map(li => li.pricebookEntryId));
            this.searchResults = results.map(r => {
                const alreadyAdded = addedKeys.has(r.pricebookEntryId);
                return {
                    ...r,
                    formattedPrice: this.formatCurrency(r.unitPrice),
                    formattedTax: r.taxPercent != null ? r.taxPercent + '%' : '0%',
                    priceBadgeClass: this.getPriceBadgeClass(r.sourcePricebookType),
                    priceBadgeLabel: this.getPriceBadgeLabel(r.sourcePricebookType),
                    hasPriceSource: !!r.sourcePricebookType,
                    productInitial: this.getProductInitial(r.productName),
                    alreadyAdded: alreadyAdded,
                    cardClass: alreadyAdded ? 'qw-product-card is-added' : 'qw-product-card'
                };
            });
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
                product.productName + ' does not have a Price List 5 entry. Ask an admin to create one before adding it to a quote.'
            );
            return;
        }

        rowCounter++;
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
            isApprovalRequired: false,
            lineTotal: (product.unitPrice || 0) * (1 + ((product.taxPercent || 0) / 100)),
            lineDescription: product.lineDescription || '',
            detailedDescription: product.detailedDescription || '',
            sourcePricebookId: product.sourcePricebookId || null,
            sourcePricebookName: product.sourcePricebook || (isService ? 'Service' : ''),
            priceBadgeClass: this.getPriceBadgeClass(product.sourcePricebookType),
            priceBadgeLabel: this.getPriceBadgeLabel(product.sourcePricebookType),
            hasPriceSource: !!product.sourcePricebookType
        };

        this.lineItems = [...this.lineItems, newItem];

        // Mark this card as added in the visible search results so the
        // user sees the "Added" pill without having to re-search.
        this.searchResults = this.searchResults.map(r => {
            if (r.pricebookEntryId !== pbeId) return r;
            return { ...r, alreadyAdded: true, cardClass: 'qw-product-card is-added' };
        });

        // Run the discount/ceiling evaluator immediately so a freshly
        // added line carries an accurate priceStatus and (for non-service
        // products) the resolved tier badge.
        if (!isService) this.refreshPricingPreview(newItem.rowId);

        this.showSuccess('Product Added', product.productName + ' added to the quote.');
    }

    handleRemoveLineItem(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const removed = this.lineItems.find(item => item.rowId === rowId);
        this.lineItems = this.lineItems
            .filter(item => item.rowId !== rowId)
            .map((item, index) => ({ ...item, rowNumber: index + 1 }));

        // If the removed product is still in the search results grid,
        // flip the "Added" pill back to a fresh Add button.
        if (removed) {
            this.searchResults = this.searchResults.map(r => {
                if (r.pricebookEntryId !== removed.pricebookEntryId) return r;
                return { ...r, alreadyAdded: false, cardClass: 'qw-product-card' };
            });
        }
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

            return updated;
        });

        // The discount-vs-Discount__c evaluator is server-side: ping it on
        // every discount/quantity/unit-price change so the UI badge,
        // mapped tier, and (re-fetched) UnitPrice stay in sync with what
        // the QuoteLineItem trigger will stamp on save.
        if (refreshTier) this.refreshPricingPreview(rowId);
    }

    // Asks the server to run the discount-vs-Discount__c algorithm and
    // returns the tier the line should map to, the UnitPrice to re-fetch
    // from that tier's PricebookEntry, and the resulting Price_Status.
    // Already-Approved lines are skipped so an approver's decision isn't
    // silently undone by a later edit. Service items short-circuit on
    // the server (status = Not Required, no remap).
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
                updated.isApprovalRequired = updated.priceStatus === 'Approval Required';
                if (preview.resolvedPricebookId) updated.sourcePricebookId = preview.resolvedPricebookId;
                if (resolvedPb) {
                    updated.sourcePricebookName = resolvedPb;
                    updated.priceBadgeClass = this.getPriceBadgeClass(resolvedPb);
                    updated.priceBadgeLabel = this.getPriceBadgeLabel(resolvedPb);
                    updated.hasPriceSource = true;
                }
                if (preview.pricebookEntryId || preview.resolvedPricebookEntryId) {
                    updated.pricebookEntryId = preview.resolvedPricebookEntryId || preview.pricebookEntryId;
                }
                // Surface the rep's self-approval ceiling on the line so
                // the row can show "Max Discount: N%". Falls back to the
                // previous value when the server preview doesn't carry
                // one (e.g. unknown profile, missing tier data).
                if (preview.ceilingTierDiscount != null) {
                    updated.maxDiscount = preview.ceilingTierDiscount;
                    updated.maxDiscountDisplay = this.formatMaxDiscount(preview.ceilingTierDiscount);
                    updated.hasMaxDiscount = true;
                }
                // UnitPrice is intentionally NOT updated from the preview.
                // The rep entered it at the PL5 list price; escalation
                // only affects the approval path, not the displayed
                // Sales Price.
                return updated;
            });
        } catch (error) {
            console.warn('Pricing preview unavailable:', error && error.body ? error.body.message : error);
        }
    }

    // 12.50% style trim — strip ".00" from clean integers and pad single
    // decimals to two so the row chip stays consistent.
    formatMaxDiscount(value) {
        if (value == null) return '';
        const n = Number(value);
        if (!isFinite(n)) return '';
        return (n % 1 === 0 ? n.toFixed(0) : n.toFixed(2)) + '%';
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
    // from the parent Opportunity's products. Price status is read from
    // the server payload (or 'Not Required' for service items); the
    // live preview re-evaluates on the first edit.
    buildRowFromServerItem(item, index) {
        rowCounter++;
        const disc = item.discount || 0;
        const isService = item.isServiceItem === true;
        const base = (item.unitPrice || 0) * (item.quantity || 0);
        const discountAmt = base * (disc / 100);
        const afterDiscount = base - discountAmt;
        const taxAmt = afterDiscount * ((item.taxPercent || 0) / 100);

        const VALID_LINE_STATUSES = ['Not Required', 'Approval Required', 'Approved'];
        let priceStatus;
        if (isService) {
            priceStatus = 'Not Required';
        } else if (VALID_LINE_STATUSES.includes(item.priceStatus)) {
            priceStatus = item.priceStatus;
        } else {
            priceStatus = 'Not Required';
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
            priceBadgeClass: this.getPriceBadgeClass(item.sourcePricebookName),
            priceBadgeLabel: this.getPriceBadgeLabel(item.sourcePricebookName),
            hasPriceSource: !!item.sourcePricebookName
        };
    }

    // ===== PRICE STATUS BADGES =====

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

    // Older quote / order saves stored the tier name in mixed casing
    // ('Price list4', 'Price list 4', etc.). Normalise to the canonical
    // 'Price List N' form so the badge maps stay clean.
    normaliseTier(name) {
        if (!name) return '';
        const m = String(name).trim().match(/^price\s*list\s*([1-5])$/i);
        if (m) return 'Price List ' + m[1];
        if (/^standard$/i.test(name)) return 'Standard';
        if (/^service$/i.test(name)) return 'Service';
        return name;
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

    // Normalises every error shape the platform throws (Apex AuraHandled,
    // record-edit-form DML errors, plain Errors, plain strings) into a
    // single, user-readable string. Strips Salesforce's "FIELD_CUSTOM_VALIDATION_EXCEPTION,"
    // and trailing ": [Field__c]" prefixes/suffixes so the toast shows the
    // human-meaningful sentence and nothing else.
    reduceErrors(error) {
        if (!error) return 'An unexpected error occurred.';
        if (typeof error === 'string') return this.cleanErrorMessage(error);

        const messages = [];
        const errors = Array.isArray(error) ? error : [error];

        for (const e of errors) {
            if (!e) continue;
            if (typeof e === 'string') {
                messages.push(this.cleanErrorMessage(e));
                continue;
            }
            if (e.body) {
                if (Array.isArray(e.body)) {
                    e.body.forEach(b => b && b.message && messages.push(this.cleanErrorMessage(b.message)));
                    continue;
                }
                if (typeof e.body === 'string') {
                    messages.push(this.cleanErrorMessage(e.body));
                    continue;
                }
                if (e.body.fieldErrors) {
                    Object.values(e.body.fieldErrors).flat().forEach(fe => {
                        if (fe && fe.message) messages.push(this.cleanErrorMessage(fe.message));
                    });
                }
                if (e.body.pageErrors) {
                    e.body.pageErrors.forEach(pe => {
                        if (pe && pe.message) messages.push(this.cleanErrorMessage(pe.message));
                    });
                }
                if (e.body.output && Array.isArray(e.body.output.errors)) {
                    e.body.output.errors.forEach(oe => {
                        if (oe && oe.message) messages.push(this.cleanErrorMessage(oe.message));
                    });
                }
                if (e.body.message) messages.push(this.cleanErrorMessage(e.body.message));
                continue;
            }
            if (e.message) messages.push(this.cleanErrorMessage(e.message));
        }

        const unique = [...new Set(messages.filter(m => m && m.trim()))];
        if (!unique.length) {
            console.error('Unhandled error format:', JSON.stringify(error));
            return 'An unexpected error occurred. Please try again or contact your administrator.';
        }
        return unique.join('\n');
    }

    // Strips Salesforce's noise ("FIELD_CUSTOM_VALIDATION_EXCEPTION, ",
    // ": [Field__c]") so the rep sees the human sentence the admin wrote.
    cleanErrorMessage(raw) {
        if (!raw) return '';
        let msg = String(raw).trim();
        msg = msg.replace(/^[A-Z_]+_EXCEPTION\s*[,:]\s*/i, '');
        msg = msg.replace(/^System\.[A-Za-z]+Exception:\s*/i, '');
        msg = msg.replace(/:\s*\[[^\]]+\]\s*$/, '');
        return msg.trim();
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title, message, variant: 'success', mode: 'dismissable'
        }));
    }

    // 'dismissable' auto-closes after the platform's default timeout (~3s)
    // and still lets the user click ✕ to close it sooner. 'sticky' kept
    // earlier toasts on screen until manually dismissed, which left
    // stale errors hanging around.
    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({
            title, message, variant: 'error', mode: 'dismissable'
        }));
    }
}