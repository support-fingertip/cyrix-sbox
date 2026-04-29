import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrdersForVisit from '@salesforce/apex/OrderBuilderController.getOrdersForVisit';

export default class OrderSessionPage extends LightningElement {
    // Visit Id - either passed by parent (visitManager) or resolved from record page
    @api recordId;
    @api isDesktop = false;

    @track orders = [];
    @track opportunityOptions = [];

    accountId;
    accountName = '';
    visitName = '';

    selectedOpportunityId = '';
    isLoading = false;

    // Builder view state — same shape as quoteSessionPage so the
    // mounted child component sees a consistent contract.
    showBuilder = false;
    builderMode = 'create'; // 'create' | 'edit'
    builderRecordId = null; // opportunityId for create OR orderId for edit

    connectedCallback() {
        this.loadOrders();
    }

    @api
    refresh() {
        this.loadOrders();
    }

    async loadOrders() {
        if (!this.recordId) return;
        this.isLoading = true;
        try {
            const session = await getOrdersForVisit({ visitId: this.recordId });
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

            this.orders = (session.orders || []).map((o, index) => ({
                ...o,
                rowNumber: index + 1,
                formattedAmount: this.formatCurrency(o.totalAmount),
                formattedCreatedDate: this.formatDate(o.createdDate),
                formattedEffective: o.effectiveDate ? this.formatDate(o.effectiveDate) : '--',
                statusClass: this.getStatusClass(o.status)
            }));
        } catch (error) {
            this.showError('Unable to load orders', this.reduceErrors(error));
            this.orders = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ===== COMPUTED =====

    get hasOrders() {
        return this.orders && this.orders.length > 0;
    }

    get orderCount() {
        return this.orders ? this.orders.length : 0;
    }

    get hasOpportunities() {
        return this.opportunityOptions && this.opportunityOptions.length > 0;
    }

    get createDisabled() {
        return !this.selectedOpportunityId;
    }

    get headerSubtitle() {
        if (this.accountName) {
            return `Orders for ${this.accountName}`;
        }
        return 'Order Session';
    }

    // ===== HANDLERS =====

    handleOpportunityChange(event) {
        this.selectedOpportunityId = event.detail.value;
    }

    handleCreateOrder() {
        if (!this.selectedOpportunityId) {
            this.showError(
                'Opportunity required',
                'Please select an opportunity before creating an order.'
            );
            return;
        }
        this.builderMode = 'create';
        this.builderRecordId = this.selectedOpportunityId;
        this.showBuilder = true;
    }

    handleEditOrder(event) {
        const orderId = event.currentTarget.dataset.orderId;
        if (!orderId) return;
        this.builderMode = 'edit';
        this.builderRecordId = orderId;
        this.showBuilder = true;
    }

    handleCloseBuilder() {
        this.showBuilder = false;
        this.builderRecordId = null;
        // Reload to pick up any newly created / updated order
        this.loadOrders();
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtovisit'));
    }

    // ===== UTILITY =====

    getStatusClass(status) {
        const base = 'status-badge';
        if (!status) return base + ' status-draft';
        const normalized = status.toLowerCase();
        if (normalized.includes('activ')) return base + ' status-active';
        if (normalized.includes('complete') || normalized.includes('fulfill')) return base + ' status-completed';
        if (normalized.includes('cancel')) return base + ' status-cancelled';
        if (normalized.includes('hold') || normalized.includes('review')) return base + ' status-review';
        return base + ' status-draft';
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
