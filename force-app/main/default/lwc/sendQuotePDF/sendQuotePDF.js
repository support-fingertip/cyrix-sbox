import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteDetails from '@salesforce/apex/QuotePDFEmailController.getQuoteDetails';
import sendQuoteEmail from '@salesforce/apex/QuotePDFEmailController.sendQuoteEmail';

export default class SendQuotePDF extends LightningElement {
    @api recordId;

    @track toAddress = '';
    @track ccAddress = '';
    @track bccAddress = '';
    @track subject = '';
    @track body = '';
    @track isLoading = true;
    @track isSending = false;
    @track cacheBuster = Date.now();
    @track hasLoaded = false;

    get pdfPreviewUrl() {
        return '/apex/ProductQuotation?id=' + this.recordId + '&t=' + this.cacheBuster;
    }

    connectedCallback() {
        this.resetState();
        this.loadQuoteDetails();
    }

    renderedCallback() {
        // Ensure data loads even if connectedCallback doesn't fire on reopen
        if (!this.hasLoaded && this.recordId) {
            this.hasLoaded = true;
            this.loadQuoteDetails();
        }
    }

    disconnectedCallback() {
        // Reset flag so next open triggers load again
        this.hasLoaded = false;
    }

    resetState() {
        this.toAddress = '';
        this.ccAddress = '';
        this.bccAddress = '';
        this.subject = '';
        this.body = '';
        this.isLoading = true;
        this.isSending = false;
        this.cacheBuster = Date.now();
    }

    loadQuoteDetails() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        getQuoteDetails({ quoteId: this.recordId })
            .then(result => {
                if (result) {
                    this.toAddress = result.contactEmail || '';
                    this.subject = result.defaultSubject || '';
                    this.body = result.defaultBody || '';
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load quote details: ' + (error.body ? error.body.message : error.message), 'error');
                this.isLoading = false;
            });
    }

    handleToChange(event) {
        this.toAddress = event.target.value;
    }

    handleCcChange(event) {
        this.ccAddress = event.target.value;
    }

    handleBccChange(event) {
        this.bccAddress = event.target.value;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleBodyChange(event) {
        this.body = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSendEmail() {
        // Validate
        if (!this.toAddress) {
            this.showToast('Error', 'Please enter a To email address', 'error');
            return;
        }
        if (!this.subject) {
            this.showToast('Error', 'Please enter a subject', 'error');
            return;
        }

        this.isSending = true;

        sendQuoteEmail({
            quoteId: this.recordId,
            toAddress: this.toAddress,
            ccAddress: this.ccAddress,
            bccAddress: this.bccAddress,
            subject: this.subject,
            body: this.body
        })
            .then(result => {
                this.isSending = false;
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Quote PDF sent successfully!', 'success');
                    this.dispatchEvent(new CloseActionScreenEvent());
                } else {
                    this.showToast('Error', result, 'error');
                }
            })
            .catch(error => {
                this.isSending = false;
                this.showToast('Error', 'Failed to send email: ' + (error.body ? error.body.message : error.message), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
