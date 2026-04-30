import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FORM_FACTOR from '@salesforce/client/formFactor';
import USER_ID from '@salesforce/user/Id';
import PRICE_STATUS_FIELD from '@salesforce/schema/Quote.Price_Status__c';
import STATUS_FIELD from '@salesforce/schema/Quote.Status';
import submitForApproval from '@salesforce/apex/QuoteActionPanelController.submitForApproval';
import getQuoteStatusOptions from '@salesforce/apex/QuoteActionPanelController.getQuoteStatusOptions';
import updateStatus from '@salesforce/apex/QuoteActionPanelController.updateStatus';

// Public-site Quote PDF endpoint used as the mobile preview redirect.
// Hard-coded against the sandbox host today; if the org needs to swap
// environments, edit this line.
const QUOTE_PDF_PUBLIC_URL =
    'https://cyrix-healthcare--sbox1.sandbox.my.salesforce-sites.com/quotepdf';

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
// the starting state, Approved / Rejected are reserved for the
// approval process to write, and Needs Review / Need Review are
// reviewer-owned states that the rep shouldn't move into manually.
const STATUS_HIDDEN = new Set([
    'Draft', 'Approved', 'Rejected', 'Needs Review', 'Need Review'
]);

// Submit-for-approval is only meaningful while the quote is sitting
// at "Approval Required" pricing. Hide the button entirely outside
// of that state so reps don't try to push an already-approved or
// already-rejected quote into the workflow again.
const APPROVAL_REQUIRED_PRICE_STATUS = 'Approval Required';

// While a quote is sitting at "Needs Review" the rep shouldn't be
// able to take any panel action — the reviewer owns the next move.
// Match case-insensitively and tolerate the singular "Need Review"
// variant some sandboxes carry.
const NEEDS_REVIEW_STATUSES = new Set(['needs review', 'need review']);

// Order creation is only meaningful once the customer has signed off.
// Match case-insensitively and tolerate the legacy 'Accepted' value
// some sandboxes still carry.
const CUSTOMER_ACCEPTED_STATUSES = new Set(['customer accepted', 'accepted']);

export default class QuoteActionPanel extends NavigationMixin(LightningElement) {
    @api recordId;

    activePopup = null;
    isBusy = false;

    // Tracks whether the popup just opened so renderedCallback can
    // scroll it into the user's viewport. Salesforce Mobile sometimes
    // wraps the LWC inside a transformed ancestor, which breaks
    // position: fixed — the overlay then falls back to its document
    // position (above the button on long record pages) and the rep
    // has to scroll up to find it.
    _popupScrollPending = false;

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

    @wire(getRecord, { recordId: '$recordId', fields: [PRICE_STATUS_FIELD, STATUS_FIELD] })
    wiredQuote;

    get priceStatus() {
        return this.wiredQuote && this.wiredQuote.data
            ? getFieldValue(this.wiredQuote.data, PRICE_STATUS_FIELD)
            : null;
    }

    get quoteStatus() {
        return this.wiredQuote && this.wiredQuote.data
            ? getFieldValue(this.wiredQuote.data, STATUS_FIELD)
            : null;
    }

    // While the quote is parked at Needs Review the reviewer owns the
    // record. The rep should only be able to push an Approval Required
    // quote forward — every other button hides until the status moves
    // back out of review.
    get lockedForReview() {
        const s = (this.quoteStatus || '').trim().toLowerCase();
        return NEEDS_REVIEW_STATUSES.has(s);
    }

    get showApprovalButton() {
        return this.priceStatus === APPROVAL_REQUIRED_PRICE_STATUS;
    }

    // The non-approval actions (PDF, Mark status, Preview, Edit
    // quote) live behind this flag so the Needs Review lock can hide
    // them in one place. Create order has its own visibility rule
    // (showCreateOrderButton) layered on top.
    get showSecondaryButtons() {
        return !this.lockedForReview;
    }

    // Order creation only makes sense after the customer has accepted
    // the quote — surfacing the button earlier lets a rep generate
    // orders against draft / pending quotes and pollute downstream
    // numbering. Hidden during Needs Review by piggy-backing on
    // showSecondaryButtons.
    get showCreateOrderButton() {
        if (!this.showSecondaryButtons) return false;
        const s = (this.quoteStatus || '').trim().toLowerCase();
        return CUSTOMER_ACCEPTED_STATUSES.has(s);
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
        } else if (action === 'createOrder') {
            this.launchCreateOrder();
        } else if (action === 'editQuote') {
            this.launchEditQuote();
        }
    }

    // ---------- create order / edit quote (delegated to existing quick actions) ----------

    launchCreateOrder() {
        // Quote.Create_Sales_Order is the LWC-typed quick action that
        // hosts newOrderCmp. Firing it via NavigationMixin keeps the
        // standard chrome (modal, header, close X) the rep is used to.
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Quote.Create_Sales_Order'
            }
        });
    }

    launchEditQuote() {
        // Quote.Edit_Quote hosts newQuoteCmp in edit mode. Same rationale
        // as the order action — let the platform open the quick action
        // modal so we don't have to embed the quote builder ourselves.
        this[NavigationMixin.Navigate]({
            type: 'standard__quickAction',
            attributes: {
                apiName: 'Quote.Edit_Quote'
            }
        });
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
        this.unlockBodyScroll();
    }

    // ---------- popup viewport plumbing ----------

    /**
     * Centers the overlay in the visible viewport on open. Called after
     * each popup state change because Salesforce Mobile can break
     * position: fixed (transformed ancestor in the shell) and leave the
     * overlay rendered at its document position — which on a long Quote
     * record page sits above the visible area, forcing the rep to scroll
     * up to find the popup.
     */
    renderedCallback() {
        if (!this._popupScrollPending) return;
        const overlay = this.template.querySelector('.qap-overlay');
        if (!overlay) return;
        this._popupScrollPending = false;
        // requestAnimationFrame defers the scroll to the next paint so
        // the overlay's final dimensions are settled.
        requestAnimationFrame(() => {
            try {
                overlay.scrollIntoView({ block: 'center', behavior: 'auto' });
            } catch (e) {
                overlay.scrollIntoView();
            }
        });
    }

    /**
     * Marks the next render as needing a viewport scroll and stops the
     * page underneath from scrolling while the popup is up. Centralises
     * the open-time housekeeping so every open* helper picks it up.
     */
    onPopupOpened() {
        this._popupScrollPending = true;
        this.lockBodyScroll();
    }

    lockBodyScroll() {
        if (typeof document === 'undefined') return;
        if (document.body && !document.body.dataset.qapScrollLocked) {
            document.body.dataset.qapScrollLocked = '1';
            document.body.style.overflow = 'hidden';
        }
    }

    unlockBodyScroll() {
        if (typeof document === 'undefined') return;
        if (document.body && document.body.dataset.qapScrollLocked) {
            document.body.style.overflow = '';
            delete document.body.dataset.qapScrollLocked;
        }
    }

    disconnectedCallback() {
        // Defensive — if the panel is removed mid-popup the lock would
        // otherwise persist across navigation.
        this.unlockBodyScroll();
    }

    // ---------- approval ----------

    openApproval() {
        this.activePopup = 'approval';
        this.onPopupOpened();
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
        this.onPopupOpened();
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
            const url = QUOTE_PDF_PUBLIC_URL +
                '?Id=' + encodeURIComponent(this.recordId) +
                '&userId=' + encodeURIComponent(USER_ID || '');
            window.open(url, '_blank');
            return;
        }

        // Desktop: navigate directly to the ProductQuotation VF page in
        // a new tab. The previous standard__quickAction → Quote.Quote_PDF
        // path silently failed in modern Lightning when a
        // VisualforcePage-typed quick action was the target — opening
        // the page URL itself is the reliable redirect.
        const vfUrl = '/apex/ProductQuotation?id=' + encodeURIComponent(this.recordId);
        window.open(vfUrl, '_blank');
    }

    // ---------- status / revision / confirm ----------

    openStatus() {
        this.activePopup = 'status';
        this.onPopupOpened();
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
        // Status -> revision/confirm transitions are still considered a
        // popup transition, so keep the overlay scrolled into view.
        this.onPopupOpened();
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