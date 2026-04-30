import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getQuotesForVisit from '@salesforce/apex/QuoteBuilderController.getQuotesForVisit';

export default class QuoteSessionPage extends LightningElement {
    // Visit Id - either passed by parent (visitManager) or resolved from record page
    @api recordId;
    @api isDesktop = false;

    @track quotes = [];
    @track opportunityOptions = [];

    accountId;
    accountName = '';
    visitName = '';

    selectedOpportunityId = '';
    isLoading = false;

    // Builder view state
    showBuilder = false;
    builderMode = 'create'; // 'create' | 'edit'
    builderRecordId = null; // opportunityId for create OR quoteId for edit
    builderFromVisitPlan = true;

    connectedCallback() {
        this.loadQuotes();
    }

    @api
    refresh() {
        this.loadQuotes();
    }

    async loadQuotes() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const session = await getQuotesForVisit({ visitId: this.recordId });
            this.visitName = session.visitName || '';
            this.accountId = session.accountId;
            this.accountName = session.accountName || '';

            this.opportunityOptions = (session.opportunities || []).map(o => ({
                label: o.stage ? `${o.opportunityName} (${o.stage})` : o.opportunityName,
                value: o.opportunityId
            }));

            if (this.opportunityOptions.length && !this.selectedOpportunityId) {
                this.selectedOpportunityId = this.opportunityOptions[0].value;
            }

            this.quotes = (session.quotes || []).map((q, index) => ({
                ...q,
                rowNumber: index + 1,
                formattedAmount: this.formatCurrency(q.grandTotal),
                formattedCreatedDate: this.formatDate(q.createdDate),
                formattedExpiry: q.expirationDate ? this.formatDate(q.expirationDate) : '--',
                statusClass: this.getStatusClass(q.status),
                // Hide the Edit button while the quote is locked. A quote
                // is locked when:
                //   - Price_Status is Approval Required (pending sign-off)
                //   - Price_Status is Approved (signed off, read-only)
                //   - Status is Customer Accepted / Accepted (the customer
                //     has agreed to the terms; subsequent edits would
                //     diverge from what was accepted, so the rep should
                //     create an order or revise instead).
                canEdit: !this.isUnderApproval(q.priceStatus)
                    && !this.isCustomerAccepted(q.status)
            }));
        } catch (error) {
            this.showError('Unable to load quotes', this.reduceErrors(error));
            this.quotes = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ===== COMPUTED =====

    get hasQuotes() {
        return this.quotes && this.quotes.length > 0;
    }

    get quoteCount() {
        return this.quotes ? this.quotes.length : 0;
    }

    get hasOpportunities() {
        return this.opportunityOptions && this.opportunityOptions.length > 0;
    }

    get createDisabled() {
        return !this.selectedOpportunityId;
    }

    get headerSubtitle() {
        if (this.accountName) {
            return `Quotes for ${this.accountName}`;
        }
        return 'Quote Session';
    }

    // ===== HANDLERS =====

    handleOpportunityChange(event) {
        this.selectedOpportunityId = event.detail.value;
    }

    handleCreateQuote() {
        if (!this.selectedOpportunityId) {
            this.showError(
                'Opportunity required',
                'Please select an opportunity before creating a quote.'
            );
            return;
        }
        this.builderMode = 'create';
        this.builderRecordId = this.selectedOpportunityId;
        this.showBuilder = true;
    }

    handleEditQuote(event) {
        const quoteId = event.currentTarget.dataset.quoteId;
        if (!quoteId) return;
        this.builderMode = 'edit';
        this.builderRecordId = quoteId;
        this.showBuilder = true;
    }

    handleCloseBuilder() {
        this.showBuilder = false;
        this.builderRecordId = null;
        // Reload to pick up any newly created / updated quote
        this.loadQuotes();
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtovisit'));
    }

    // ===== UTILITY =====

    getStatusClass(status) {
        const base = 'status-badge';
        if (!status) return base + ' status-draft';
        const normalized = status.toLowerCase();
        if (normalized.includes('accept')) return base + ' status-accepted';
        if (normalized.includes('present') || normalized.includes('sent')) return base + ' status-sent';
        if (normalized.includes('reject') || normalized.includes('denied')) return base + ' status-rejected';
        if (normalized.includes('review')) return base + ' status-review';
        return base + ' status-draft';
    }

    // Quote is "under approval" when the price-status field is sitting
    // at 'Approval Required' (waiting for a reviewer) or 'Approved' (the
    // record has been signed off and is now read-only). Editing in
    // either state would either invalidate the pending approval or
    // tamper with an approved record, so the row hides the Edit button.
    isUnderApproval(priceStatus) {
        if (!priceStatus) return false;
        const normalized = String(priceStatus).trim().toLowerCase();
        return normalized === 'approval required' || normalized === 'approved';
    }

    // Quote has been accepted by the customer — locking it is the BRD
    // intent (any change after acceptance must come through the
    // revision flow, not a silent edit). Tolerates the legacy
    // 'Accepted' picklist variant alongside the canonical
    // 'Customer Accepted'.
    isCustomerAccepted(status) {
        if (!status) return false;
        const normalized = String(status).trim().toLowerCase();
        return normalized === 'customer accepted' || normalized === 'accepted';
    }

    formatCurrency(value) {
        if (value == null) return '--';
        try {
            return new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency: 'INR',
                minimumFractionDigits: 2
            }).format(value);
        } catch (e) {
            return value;
        }
    }

    formatDate(value) {
        if (!value) return '';
        try {
            const d = new Date(value);
            return d.toLocaleDateString('en-IN', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
        } catch (e) {
            return value;
        }
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error' }));
    }
}