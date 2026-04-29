import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrdersForVisit from '@salesforce/apex/OrderBuilderController.getOrdersForVisit';

export default class OrderSessionPage extends LightningElement {
    @api recordId;
    @api isDesktop = false;

    @track acceptedQuotes = [];
    @track activeOrders = [];

    accountId;
    accountName = '';
    visitName = '';

    isLoading = false;

    // Builder view state
    showBuilder = false;
    // 'convert' (recordId is a Quote -> newOrderCmp prefills from quote)
    // 'edit'    (recordId is an existing Order -> newOrderCmp loads in edit mode)
    builderMode = 'convert';
    builderRecordId = null;
    builderFromVisitPlan = true;

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

            this.acceptedQuotes = (session.acceptedQuotes || []).map((q, i) => ({
                ...q,
                rowNumber: i + 1,
                formattedAmount: this.formatCurrency(q.grandTotal),
                formattedExpiry: q.expirationDate ? this.formatDate(q.expirationDate) : '--',
                formattedCreatedDate: this.formatDate(q.createdDate)
            }));

            this.activeOrders = (session.activeOrders || []).map((o, i) => ({
                ...o,
                rowNumber: i + 1,
                formattedAmount: this.formatCurrency(o.totalAmount),
                formattedEffective: o.effectiveDate ? this.formatDate(o.effectiveDate) : '--',
                formattedCreatedDate: this.formatDate(o.createdDate)
            }));
        } catch (error) {
            this.showError('Unable to load orders', this.reduceErrors(error));
            this.acceptedQuotes = [];
            this.activeOrders = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ===== COMPUTED =====

    get hasAcceptedQuotes() {
        return this.acceptedQuotes && this.acceptedQuotes.length > 0;
    }

    get hasActiveOrders() {
        return this.activeOrders && this.activeOrders.length > 0;
    }

    get acceptedQuoteCount() {
        return this.acceptedQuotes ? this.acceptedQuotes.length : 0;
    }

    get activeOrderCount() {
        return this.activeOrders ? this.activeOrders.length : 0;
    }

    get headerSubtitle() {
        if (this.accountName) {
            return `Orders for ${this.accountName}`;
        }
        return 'Order Session';
    }

    // ===== HANDLERS =====

    handleConvertToOrder(event) {
        const quoteId = event.currentTarget.dataset.quoteId;
        if (!quoteId) return;
        this.builderMode = 'convert';
        this.builderRecordId = quoteId;
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
        this.loadOrders();
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('backtovisit'));
    }

    // ===== UTILITY =====

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
