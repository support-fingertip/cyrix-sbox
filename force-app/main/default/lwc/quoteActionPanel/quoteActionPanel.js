import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FORM_FACTOR from '@salesforce/client/formFactor';
import USER_ID from '@salesforce/user/Id';
import QUOTE_PDF_PUBLIC_URL from '@salesforce/label/c.Quote_PDF_Public_URL';
import PRICE_STATUS_FIELD from '@salesforce/schema/Quote.Price_Status__c';
import submitForApproval from '@salesforce/apex/QuoteActionPanelController.submitForApproval';
import getQuoteStatusOptions from '@salesforce/apex/QuoteActionPanelController.getQuoteStatusOptions';
import updateStatus from '@salesforce/apex/QuoteActionPanelController.updateStatus';

// Friendly one-liner per known status value. Anything not listed
// falls back to "Set status to <label>".
const STATUS_DESCRIPTIONS = {
    'Revision': 'Send back with reason',
    'Customer accepted': 'Customer approved',
    'Accepted': 'Customer approved',
    'Denied': 'Customer rejected',
    'Closed': 'No further action',
    'Needs Review': 'Awaiting internal review',
    'In Review': 'Approval in progress',
    'Presented': 'Sent to customer'
};

// Statuses the rep should not change to from this panel — Draft is
// the starting state, and Approved / Rejected are reserved for the
// approval process to write.
const STATUS_HIDDEN = new Set(['Draft', 'Approved', 'Rejected']);

// Submit-for-approval is only meaningful while the quote is sitting
// at "Approval Required" pricing. Hide the button entirely outside
// of that state so reps don't try to push an already-approved or
// already-rejected quote into the workflow again.
const APPROVAL_REQUIRED_PRICE_STATUS = 'Approval Required';

export default class QuoteActionPanel extends NavigationMixin(LightningElement) {
    @api recordId;

    activePopup = null;
    isBusy = false;

    approvalComments = '';
    approvalError = '';

    statusOptions = [];
    statusLoading = false;
    pendingStatusValue = '';
    pendingStatusLabel = '';

    revisionReason = '';
    revisionError = '';

    confirmMessage = '';

    // ---------- price-status wire ----------

    @wire(getRecord, { recordId: '$recordId', fields: [PRICE_STATUS_FIELD] })
    wiredQuote;

    get priceStatus() {
        return this.wiredQuote && this.wiredQuote.data
            ? getFieldValue(this.wiredQuote.data, PRICE_STATUS_FIELD)
            : null;
    }

    get showApprovalButton() {
        return this.priceStatus === APPROVAL_REQUIRED_PRICE_STATUS;
    }

    // ---------- popup-state getters ----------

    get isPopupOpen() { return !!this.activePopup; }
    get isApproval() { return this.activePopup === 'approval'; }
    get isStatus()   { return this.activePopup === 'status'; }
    get isRevision() { return this.activePopup === 'revision'; }
    get isConfirm()  { return this.activePopup === 'confirm'; }
    get isSendPdf()  { return this.activePopup === 'sendpdf'; }

    get popupTitle() {
        switch (this.activePopup) {
            case 'approval': return 'Submit for approval';
            case 'status':   return 'Mark status';
            case 'revision': return 'Reason for revision';
            case 'confirm':  return 'Confirm — ' + this.pendingStatusLabel;
            default:         return '';
        }
    }

    get hasStatusOptions() {
        return this.statusOptions && this.statusOptions.length > 0;
    }

    get approvalTextareaClass() {
        return 'qap-textarea' + (this.approvalError ? ' qap-textarea--error' : '');
    }
    get revisionTextareaClass() {
        return 'qap-textarea' + (this.revisionError ? ' qap-textarea--error' : '');
    }

    // ---------- button dispatch ----------

    handleAction(event) {
        const action = event.currentTarget.dataset.action;
        if (action === 'approval') {
            this.openApproval();
        } else if (action === 'pdf') {
            this.openSendPdf();
        } else if (action === 'status') {
            this.openStatus();
        } else if (action === 'preview') {
            this.launchPreview();
        }
    }

    handleOverlayClick() { this.closePopup(); }
    stopPropagation(event) { event.stopPropagation(); }

    closePopup() {
        this.activePopup = null;
        this.isBusy = false;
        this.approvalComments = '';
        this.approvalError = '';
        this.revisionReason = '';
        this.revisionError = '';
        this.pendingStatusValue = '';
        this.pendingStatusLabel = '';
        this.confirmMessage = '';
    }

    // ---------- approval ----------

    openApproval() {
        this.activePopup = 'approval';
    }

    handleApprovalCommentsChange(event) {
        this.approvalComments = event.target.value;
        if (this.approvalError) this.approvalError = '';
    }

    handleApprovalSubmit() {
        // Comments are optional — submit whatever the rep typed
        // (including blank).
        const v = (this.approvalComments || '').trim();
        this.isBusy = true;
        submitForApproval({ quoteId: this.recordId, comments: v })
            .then(() => {
                this.showToast('Submitted for approval', '', 'success');
                this.closePopup();
            })
            .catch(error => {
                this.isBusy = false;
                this.approvalError = this.errorMessage(error, 'Could not submit');
            });
    }

    // ---------- send pdf (embedded sendQuoteDocument) ----------

    openSendPdf() {
        this.activePopup = 'sendpdf';
    }

    /**
     * sendQuoteDocument dispatches a bubbling, composed `dismiss`
     * custom event after Cancel / Send completes, so we just dismiss
     * the panel on receipt. The wrapper div also listens for the
     * same event so a stopPropagation upstream still reaches us.
     */
    handleEmbedClose() {
        this.closePopup();
    }

    // ---------- preview ----------

    launchPreview() {
        // Salesforce Mobile can't host the desktop Visualforce quick
        // action reliably (the modal renders blank on iOS, the user
        // can't tap to download the PDF, etc.). On mobile, redirect
        // to the public-site /quotepdf URL in a new tab — the route
        // resolves the Quote by Id + userId and returns a properly
        // rendered PDF the device's browser can open.
        if (FORM_FACTOR === 'Small') {
            const base = (QUOTE_PDF_PUBLIC_URL || '').trim();
            if (!base) {
                this.showToast(
                    'Preview unavailable',
                    'Quote_PDF_Public_URL custom label is not configured.',
                    'error'
                );
                return;
            }
            const sep = base.indexOf('?') >= 0 ? '&' : '?';
            const url = base + sep + 'Id=' + encodeURIComponent(this.recordId) +
                '&userId=' + encodeURIComponent(USER_ID || '');
            window.open(url, '_blank');
            return;
        }

        // Desktop: Quote.Quote_PDF is a VisualforcePage quick action
        // that launches the ProductQuotation page in a Salesforce-managed
        // modal. Reusing it gets us a battle-tested PDF preview without
        // re-implementing the iframe + timeout dance here.
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Quote.Quote_PDF'
            }
        });
    }

    // ---------- status / revision / confirm ----------

    openStatus() {
        this.activePopup = 'status';
        if (this.statusOptions.length === 0) {
            this.statusLoading = true;
            getQuoteStatusOptions({ quoteId: this.recordId })
                .then(options => {
                    this.statusOptions = (options || [])
                        .filter(o => !STATUS_HIDDEN.has(o.value) && !STATUS_HIDDEN.has(o.label))
                        .map(o => ({
                            ...o,
                            desc: STATUS_DESCRIPTIONS[o.label] || ('Set status to ' + o.label)
                        }));
                    this.statusLoading = false;
                })
                .catch(error => {
                    this.statusLoading = false;
                    this.showToast('Couldn’t load statuses',
                        this.errorMessage(error, 'Failed to load Status picklist'), 'error');
                    this.closePopup();
                });
        }
    }

    handleStatusPick(event) {
        const value = event.currentTarget.dataset.value;
        const picked = this.statusOptions.find(o => o.value === value);
        if (!picked) return;
        this.pendingStatusValue = picked.value;
        this.pendingStatusLabel = picked.label;

        if (picked.value === 'Revision') {
            this.activePopup = 'revision';
        } else {
            this.confirmMessage = this.buildConfirmMessage(picked.label);
            this.activePopup = 'confirm';
        }
    }

    buildConfirmMessage(label) {
        const lower = label.toLowerCase();
        if (lower === 'closed') {
            return 'Close this quote? No further changes will be allowed.';
        }
        if (lower === 'denied') {
            return 'Mark this quote as ' + label + '?';
        }
        if (lower === 'customer accepted' || lower === 'accepted') {
            return 'Mark this quote as accepted by the customer?';
        }
        return 'Set the quote status to ' + label + '?';
    }

    handleRevisionReasonChange(event) {
        this.revisionReason = event.target.value;
        if (this.revisionError) this.revisionError = '';
    }

    handleRevisionSave() {
        const v = (this.revisionReason || '').trim();
        if (!v) {
            this.revisionError = 'A reason is required to mark for revision.';
            return;
        }
        if (v.length < 10) {
            this.revisionError = 'Please provide at least 10 characters of detail.';
            return;
        }

        this.isBusy = true;
        updateStatus({
            quoteId: this.recordId,
            newStatus: this.pendingStatusValue,
            reason: v
        })
            .then(() => {
                this.showToast('Status updated to Revision', '', 'success');
                this.closePopup();
            })
            .catch(error => {
                this.isBusy = false;
                this.revisionError = this.errorMessage(error, 'Could not save reason');
            });
    }

    handleConfirmYes() {
        this.isBusy = true;
        updateStatus({
            quoteId: this.recordId,
            newStatus: this.pendingStatusValue,
            reason: null
        })
            .then(() => {
                this.showToast('Status updated to ' + this.pendingStatusLabel, '', 'success');
                this.closePopup();
            })
            .catch(error => {
                this.isBusy = false;
                this.showToast('Couldn’t update status',
                    this.errorMessage(error, 'Status update failed'), 'error');
            });
    }

    // ---------- shared helpers ----------

    errorMessage(error, fallback) {
        if (error && error.body && error.body.message) return error.body.message;
        if (error && error.message) return error.message;
        return fallback;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}