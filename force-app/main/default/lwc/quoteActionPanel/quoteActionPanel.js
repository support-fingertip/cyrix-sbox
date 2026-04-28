import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
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
    'Rejected': 'Customer rejected',
    'Closed': 'No further action',
    'Draft': 'Still being prepared',
    'Needs Review': 'Awaiting internal review',
    'In Review': 'Approval in progress',
    'Approved': 'Internally approved',
    'Presented': 'Sent to customer'
};

const PREVIEW_TIMEOUT_MS = 12000;

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

    previewLoading = false;
    previewError = false;
    previewErrorMessage = '';
    previewCacheBuster = Date.now();
    _previewTimeoutId = null;

    // ---------- popup-state getters ----------

    get isPopupOpen() { return !!this.activePopup; }
    get isApproval() { return this.activePopup === 'approval'; }
    get isStatus()   { return this.activePopup === 'status'; }
    get isRevision() { return this.activePopup === 'revision'; }
    get isConfirm()  { return this.activePopup === 'confirm'; }
    get isPreview()  { return this.activePopup === 'preview'; }

    get popupTitle() {
        switch (this.activePopup) {
            case 'approval': return 'Submit for approval';
            case 'status':   return 'Mark status';
            case 'revision': return 'Reason for revision';
            case 'confirm':  return 'Confirm — ' + this.pendingStatusLabel;
            case 'preview':  return 'Preview quote PDF';
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

    get previewUrl() {
        return '/apex/ProductQuotation?id=' + this.recordId + '&t=' + this.previewCacheBuster;
    }

    get previewIframeClass() {
        return this.previewLoading ? 'qap-iframe--hidden' : '';
    }

    // ---------- button dispatch ----------

    handleAction(event) {
        const action = event.currentTarget.dataset.action;
        if (action === 'approval') {
            this.openApproval();
        } else if (action === 'pdf') {
            this.launchSendPdf();
        } else if (action === 'status') {
            this.openStatus();
        } else if (action === 'preview') {
            this.openPreview();
        }
    }

    handleOverlayClick() { this.closePopup(); }
    stopPropagation(event) { event.stopPropagation(); }

    closePopup() {
        if (this._previewTimeoutId) {
            clearTimeout(this._previewTimeoutId);
            this._previewTimeoutId = null;
        }
        this.activePopup = null;
        this.isBusy = false;
        this.approvalComments = '';
        this.approvalError = '';
        this.revisionReason = '';
        this.revisionError = '';
        this.pendingStatusValue = '';
        this.pendingStatusLabel = '';
        this.confirmMessage = '';
        this.previewLoading = false;
        this.previewError = false;
        this.previewErrorMessage = '';
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
        const v = (this.approvalComments || '').trim();
        if (!v) {
            this.approvalError = 'Please add a comment before submitting.';
            return;
        }
        if (v.length < 5) {
            this.approvalError = 'Comment is too short — add a bit more detail.';
            return;
        }

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

    // ---------- send pdf (delegated to existing quick action) ----------

    launchSendPdf() {
        // Reuse the merged sendQuoteDocument quick action so we don't
        // duplicate the email/WhatsApp form. NavigationMixin's
        // standard__quickAction page reference type opens any quick
        // action by API name.
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Quote.Send_Quote_PDF'
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
                    this.statusOptions = (options || []).map(o => ({
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
        if (lower === 'denied' || lower === 'rejected') {
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

    // ---------- preview ----------

    openPreview() {
        this.activePopup = 'preview';
        this.previewError = false;
        this.previewErrorMessage = '';
        this.previewLoading = true;
        this.previewCacheBuster = Date.now();

        // 12s safety timeout — VF page generation can hang on large
        // quotes or when the underlying data has issues; the rep
        // should get an actionable message rather than an endless
        // spinner.
        if (this._previewTimeoutId) clearTimeout(this._previewTimeoutId);
        this._previewTimeoutId = setTimeout(() => {
            if (this.previewLoading) {
                this.previewLoading = false;
                this.previewError = true;
                this.previewErrorMessage =
                    'The preview is taking longer than expected. ' +
                    'The Quote PDF may still be generating, or the ProductQuotation Visualforce ' +
                    'page may be returning an error. Try again in a moment, or open the record ' +
                    'and use the standard Quote PDF action.';
            }
        }, PREVIEW_TIMEOUT_MS);
    }

    handlePreviewLoaded() {
        this.previewLoading = false;
        if (this._previewTimeoutId) {
            clearTimeout(this._previewTimeoutId);
            this._previewTimeoutId = null;
        }
    }

    handlePreviewError() {
        this.previewLoading = false;
        this.previewError = true;
        this.previewErrorMessage =
            'The Quote PDF preview failed to load. This usually means the ProductQuotation ' +
            'Visualforce page errored — open the record’s standard PDF action for the full ' +
            'platform error.';
        if (this._previewTimeoutId) {
            clearTimeout(this._previewTimeoutId);
            this._previewTimeoutId = null;
        }
    }

    handlePreviewRetry() {
        this.openPreview();
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
