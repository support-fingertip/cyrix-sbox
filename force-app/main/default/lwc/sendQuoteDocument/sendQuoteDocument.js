import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteDocumentInfo from '@salesforce/apex/SendQuoteDocumentController.getQuoteDocumentInfo';
import sendQuoteEmail from '@salesforce/apex/SendQuoteDocumentController.sendQuoteEmail';
import sendQuoteViaWhatsApp from '@salesforce/apex/SendQuoteDocumentController.sendQuoteViaWhatsApp';

const RICH_TEXT_FORMATS = [
    'font', 'size', 'bold', 'italic', 'underline', 'strike',
    'list', 'indent', 'align', 'link', 'clean', 'color', 'background',
    'header', 'direction'
];

export default class SendQuoteDocument extends LightningElement {
    _recordId;

    @api
    get recordId() { return this._recordId; }
    set recordId(value) {
        this._recordId = value;
        // The framework sometimes sets @api recordId AFTER
        // connectedCallback fires (especially on the
        // lightning__RecordAction launch path). Trigger loadInfo
        // reactively whenever the id arrives so we don't sit on a
        // blank form forever waiting for an invoke() that may also
        // pre-empt the id.
        if (value) this.loadInfo();
    }

    channel = 'email';
    isLoading = true;
    isSending = false;
    showPreview = false;
    defaultsLoaded = false;
    cacheBuster = Date.now();

    fromAddress = '';
    toAddress = '';
    ccAddress = '';
    bccAddress = '';
    subject = '';
    body = '';

    customerName = '';
    countryCode = '+91';
    phone = '';
    whatsappTemplateName = '';

    accountName = '';
    fileName = '';
    richTextFormats = RICH_TEXT_FORMATS;

    connectedCallback() {
        this.reset();
        // Don't call loadInfo here — the @api recordId setter
        // already triggers it as soon as the framework wires the id.
        // Calling it from connectedCallback as well would either
        // duplicate the load or fire with a null id and waste a
        // round-trip.
    }

    @api invoke() {
        this.reset();
        // The LWC instance is reused across quick action opens, so
        // refresh defaults on every invocation to pick up edits to
        // the Quote / Opportunity since the last open.
        this.loadInfo();
    }

    reset() {
        this.isSending = false;
        this.showPreview = false;
        this.cacheBuster = Date.now();
    }

    loadInfo() {
        if (!this.recordId) {
            // connectedCallback can fire before the framework hands us
            // the record id on some launch paths; the @api invoke()
            // call that follows always carries it. Skip the wasted
            // call rather than running SOQL with a null Id.
            this.isLoading = false;
            return;
        }
        this.isLoading = true;
        // Force lightning-input-rich-text to remount with the next
        // body value — its `value` attribute is initial-only, so an
        // in-place update from a stale empty body to the populated
        // template wouldn't reach the editor.
        this.defaultsLoaded = false;

        getQuoteDocumentInfo({ quoteId: this.recordId })
            .then(info => {
                this.fromAddress = info.fromAddress || '';
                this.toAddress = info.defaultToAddress || '';
                this.subject = info.defaultSubject || '';
                this.body = info.defaultBody || '';
                this.customerName = info.recipientName || '';
                this.countryCode = info.phoneCountryCode || '+91';
                this.phone = info.phone || '';
                this.whatsappTemplateName = info.whatsappTemplateName || '';
                this.accountName = info.accountName || '';
                this.fileName = info.fileName || '';
                this.isLoading = false;
                this.defaultsLoaded = true;
            })
            .catch(error => {
                this.isLoading = false;
                this.defaultsLoaded = true;
                this.showToast('Error', this.errorMessage(error, 'Failed to load quote'), 'error');
            });
    }

    get isEmailChannel() { return this.channel === 'email'; }
    get isWhatsAppChannel() { return this.channel === 'whatsapp'; }

    get emailTabClass() {
        return 'sqd-tab-btn' + (this.isEmailChannel ? ' sqd-tab-btn--active' : '');
    }
    get whatsAppTabClass() {
        return 'sqd-tab-btn' + (this.isWhatsAppChannel ? ' sqd-tab-btn--active' : '');
    }

    get headerMeta() {
        return this.accountName ? 'Account · ' + this.accountName : '';
    }

    get attachmentFileName() {
        return this.fileName || 'Quote.pdf';
    }

    get pdfPreviewUrl() {
        return '/apex/ProductQuotation?id=' + this.recordId + '&t=' + this.cacheBuster;
    }

    get sendButtonLabel() {
        if (this.isSending) return 'Sending…';
        return this.isEmailChannel ? 'Send via email' : 'Send via WhatsApp';
    }

    get isSendDisabled() {
        if (this.isSending) return true;
        if (this.isEmailChannel) {
            return !this.toAddress || !this.subject;
        }
        return !this.phone || !this.customerName;
    }

    get countryCodeOptions() {
        const base = [
            { value: '+91', label: '🇮🇳 +91' },
            { value: '+1', label: '🇺🇸 +1' },
            { value: '+44', label: '🇬🇧 +44' },
            { value: '+971', label: '🇦🇪 +971' },
            { value: '+966', label: '🇸🇦 +966' },
            { value: '+65', label: '🇸🇬 +65' }
        ];
        const cc = this.countryCode;
        if (cc && !base.some(o => o.value === cc)) {
            base.unshift({ value: cc, label: cc });
        }
        return base;
    }

    handleSelectEmail() { this.channel = 'email'; }
    handleSelectWhatsApp() { this.channel = 'whatsapp'; }

    handleToChange(event) { this.toAddress = event.target.value; }
    handleCcChange(event) { this.ccAddress = event.target.value; }
    handleBccChange(event) { this.bccAddress = event.target.value; }
    handleSubjectChange(event) { this.subject = event.target.value; }
    handleBodyChange(event) {
        this.body = event.detail ? event.detail.value : event.target.value;
    }
    handlePhoneChange(event) { this.phone = event.target.value; }
    handleCountryCodeChange(event) { this.countryCode = event.target.value; }

    handleOpenPreview() {
        this.cacheBuster = Date.now();
        this.showPreview = true;
    }
    handleClosePreview() { this.showPreview = false; }
    stopPropagation(event) { event.stopPropagation(); }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleSend() {
        if (this.isEmailChannel) {
            this.sendEmail();
        } else {
            this.sendWhatsApp();
        }
    }

    sendEmail() {
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
                this.showToast('Error', this.errorMessage(error, 'Failed to send email'), 'error');
            });
    }

    sendWhatsApp() {
        if (!this.phone) {
            this.showToast('Error', 'Please enter a phone number', 'error');
            return;
        }
        if (!this.customerName) {
            this.showToast('Error', 'Please enter the recipient name', 'error');
            return;
        }

        const fullPhone = this.composePhone();
        this.isSending = true;
        sendQuoteViaWhatsApp({
            quoteId: this.recordId,
            phone: fullPhone,
            recipientName: this.customerName
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
                this.showToast('Error', this.errorMessage(error, 'Failed to send'), 'error');
            });
    }

    composePhone() {
        const local = (this.phone || '').replace(/\s+/g, '');
        if (!local) return '';
        if (local.startsWith('+')) return local;
        const code = (this.countryCode || '').replace(/\s+/g, '');
        return code + local;
    }

    errorMessage(error, fallback) {
        if (error && error.body && error.body.message) return fallback + ': ' + error.body.message;
        if (error && error.message) return fallback + ': ' + error.message;
        return fallback;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}