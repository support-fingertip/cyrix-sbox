import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteDetails from '@salesforce/apex/QuotePDFEmailController.getQuoteDetails';
import sendQuoteEmail from '@salesforce/apex/QuotePDFEmailController.sendQuoteEmail';

export default class SendQuotePDF extends LightningElement {
    @api recordId;

    toAddress = '';
    ccAddress = '';
    bccAddress = '';
    subject = '';
    body = '';
    isLoading = true;
    isSending = false;
    cacheBuster = Date.now();

    // Step flags
    showPreview = true;
    showEmailForm = false;

    get pdfPreviewUrl() {
        return '/apex/ProductQuotation?id=' + this.recordId + '&t=' + this.cacheBuster;
    }

    // @api invoke() is called by Salesforce every time the Quick Action is opened
    @api invoke() {
        this.resetAndLoad();
    }

    connectedCallback() {
        this.resetAndLoad();
    }

    resetAndLoad() {
        // Reset all state on each open
        this.toAddress = '';
        this.ccAddress = '';
        this.bccAddress = '';
        this.subject = '';
        this.body = '';
        this.isLoading = true;
        this.isSending = false;
        this.cacheBuster = Date.now();
        // Reset to Step 1 (PDF Preview)
        this.showPreview = true;
        this.showEmailForm = false;
        this.loadQuoteDetails();
    }

    loadQuoteDetails() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
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

    handleShowEmailForm() {
        this.showPreview = false;
        this.showEmailForm = true;
    }

    handleBackToPreview() {
        this.showPreview = true;
        this.showEmailForm = false;
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
