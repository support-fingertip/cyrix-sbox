import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteInfo from '@salesforce/apex/WhatsAppQuoteSender.getQuoteInfo';
import sendQuoteViaWhatsApp from '@salesforce/apex/WhatsAppQuoteSender.sendQuoteViaWhatsApp';

export default class SendQuoteWhatsApp extends LightningElement {
    @api recordId;

    phone = '';
    recipientName = '';
    quoteName = '';
    isSending = false;
    isLoading = true;
    cacheBuster = Date.now();

    connectedCallback() {
        this.loadQuoteInfo();
    }

    @api invoke() {
        this.isSending = false;
        this.cacheBuster = Date.now();
        this.loadQuoteInfo();
    }

    loadQuoteInfo() {
        this.isLoading = true;
        getQuoteInfo({ quoteId: this.recordId })
            .then(result => {
                this.phone = result.phone || '';
                this.recipientName = result.recipientName || '';
                this.quoteName = result.quoteName || '';
                this.isLoading = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Failed to load quote info: ' +
                    (error.body ? error.body.message : 'Unknown error'), 'error');
            });
    }

    get pdfPreviewUrl() {
        return '/apex/ProductQuotation?id=' + this.recordId + '&t=' + this.cacheBuster;
    }

    get isSendDisabled() {
        return this.isSending || !this.phone || !this.recipientName;
    }

    get sendButtonLabel() {
        return this.isSending ? 'Sending...' : 'Send via WhatsApp';
    }

    handlePhoneChange(event) {
        this.phone = event.target.value;
    }

    handleNameChange(event) {
        this.recipientName = event.target.value;
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSend() {
        if (!this.phone) {
            this.showToast('Error', 'Please enter a phone number', 'error');
            return;
        }
        if (!this.recipientName) {
            this.showToast('Error', 'Please enter the recipient name', 'error');
            return;
        }

        this.isSending = true;

        sendQuoteViaWhatsApp({
            quoteId: this.recordId,
            phone: this.phone,
            recipientName: this.recipientName
        })
            .then(result => {
                this.isSending = false;
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Quote PDF sent via WhatsApp!', 'success');
                    this.dispatchEvent(new CloseActionScreenEvent());
                } else {
                    this.showToast('Error', result, 'error');
                }
            })
            .catch(error => {
                this.isSending = false;
                this.showToast('Error', 'Failed to send: ' +
                    (error.body ? error.body.message : 'Unknown error'), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
