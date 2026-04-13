import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import sendQuoteEmail from '@salesforce/apex/QuotePDFEmailController.sendQuoteEmail';

// Fields from the Quote record and its supported cross-references
import QUOTE_NAME from '@salesforce/schema/Quote.Name';
import QUOTE_NUMBER from '@salesforce/schema/Quote.QuoteNumber';
import QUOTE_ID_C from '@salesforce/schema/Quote.Quote_Id__c';
import QUOTE_OWNER_ID from '@salesforce/schema/Quote.OwnerId';
import ACCOUNT_NAME from '@salesforce/schema/Quote.Account.Name';
import CONTACT_NAME from '@salesforce/schema/Quote.Contact.Name';
import CONTACT_EMAIL from '@salesforce/schema/Quote.Contact.Email';
import OPPORTUNITY_NAME from '@salesforce/schema/Quote.Opportunity.Name';
import OPPORTUNITY_EMAIL from '@salesforce/schema/Quote.Opportunity.Email__c';

// Owner is polymorphic on Quote, so fetch the User record separately via OwnerId
import USER_NAME from '@salesforce/schema/User.Name';
import USER_EMAIL from '@salesforce/schema/User.Email';
import USER_TITLE from '@salesforce/schema/User.Title';

const QUOTE_FIELDS = [
    QUOTE_NAME, QUOTE_NUMBER, QUOTE_ID_C, QUOTE_OWNER_ID,
    ACCOUNT_NAME,
    CONTACT_NAME, CONTACT_EMAIL,
    OPPORTUNITY_NAME, OPPORTUNITY_EMAIL
];

const USER_FIELDS = [USER_NAME, USER_EMAIL, USER_TITLE];

export default class SendQuotePDF extends LightningElement {
    @api recordId;

    toAddress = '';
    ccAddress = '';
    bccAddress = '';
    subject = '';
    body = '';
    isSending = false;
    showEmailForm = false;
    cacheBuster = Date.now();

    // Cached values from the Quote wire
    _quoteName = '';
    _quoteNumber = '';
    _quoteIdC = '';
    _accountName = '';
    _contactName = '';
    _contactEmail = '';
    _opportunityName = '';
    _opportunityEmail = '';
    _ownerId = null;

    // Cached values from the User wire
    _ownerName = '';
    _ownerEmail = '';
    _ownerTitle = '';

    richTextFormats = [
        'font', 'size', 'bold', 'italic', 'underline', 'strike',
        'list', 'indent', 'align', 'link', 'clean', 'color', 'background',
        'header', 'direction'
    ];

    // Wire: load Quote fields
    @wire(getRecord, { recordId: '$recordId', fields: QUOTE_FIELDS })
    wiredQuote({ data, error }) {
        if (data) {
            this._quoteName = getFieldValue(data, QUOTE_NAME) || '';
            this._quoteNumber = getFieldValue(data, QUOTE_NUMBER) || '';
            this._quoteIdC = getFieldValue(data, QUOTE_ID_C) || '';
            this._accountName = getFieldValue(data, ACCOUNT_NAME) || '';
            this._contactName = getFieldValue(data, CONTACT_NAME) || '';
            this._contactEmail = getFieldValue(data, CONTACT_EMAIL) || '';
            this._opportunityName = getFieldValue(data, OPPORTUNITY_NAME) || '';
            this._opportunityEmail = getFieldValue(data, OPPORTUNITY_EMAIL) || '';
            this._ownerId = getFieldValue(data, QUOTE_OWNER_ID) || null;
            this.buildDefaults();
        } else if (error) {
            this.showToast('Error', 'Failed to load quote: ' +
                (error.body && error.body.message ? error.body.message : 'Unknown error'), 'error');
        }
    }

    // Wire: load Owner (User) fields using the OwnerId from the Quote wire
    @wire(getRecord, { recordId: '$_ownerId', fields: USER_FIELDS })
    wiredOwner({ data, error }) {
        if (data) {
            this._ownerName = getFieldValue(data, USER_NAME) || '';
            this._ownerEmail = getFieldValue(data, USER_EMAIL) || '';
            this._ownerTitle = getFieldValue(data, USER_TITLE) || '';
            this.buildDefaults();
        } else if (error) {
            // Owner might be a Queue or inaccessible — not fatal
            this._ownerName = '';
            this._ownerEmail = '';
            this._ownerTitle = '';
        }
    }

    // Build the default To / Subject / Body from the currently loaded data
    buildDefaults() {
        // To: Opportunity email -> Contact email -> Owner email
        this.toAddress = this._opportunityEmail || this._contactEmail || this._ownerEmail || '';

        // Subject: "Quotation <QuoteId/Number> - <Opportunity or Account Name>"
        const quoteRef = this._quoteIdC || this._quoteNumber || this._quoteName;
        const contextName = this._opportunityName || this._accountName || '';
        if (quoteRef && contextName) {
            this.subject = 'Quotation ' + quoteRef + ' - ' + contextName;
        } else if (quoteRef) {
            this.subject = 'Quotation ' + quoteRef;
        } else {
            this.subject = '';
        }

        // Body: professional HTML template
        const greetingName = this._contactName || this._accountName || 'Sir/Madam';
        const projectName = this._opportunityName || this._quoteName;
        const signatureTitle = this._ownerTitle ? '<br/>' + this._ownerTitle : '';

        this.body =
            '<p>Dear ' + greetingName + ',</p>' +
            '<p>I hope this email finds you well.</p>' +
            '<p>Following our recent discussions, I am pleased to present our detailed ' +
            'proposal for ' + projectName + '. Attached to this email, you will find ' +
            'the proposal document which includes a comprehensive estimate for the project.</p>' +
            '<p>Best regards,</p>' +
            '<p><strong>For Cyrix Healthcare Pvt. Ltd</strong></p>' +
            '<p>' + this._ownerName + signatureTitle + '</p>';
    }

    get pdfPreviewUrl() {
        return '/apex/ProductQuotation?id=' + this.recordId + '&t=' + this.cacheBuster;
    }

    // @api invoke() is called by Salesforce every time the Quick Action is opened
    @api invoke() {
        this.reset();
    }

    connectedCallback() {
        this.reset();
    }

    reset() {
        this.ccAddress = '';
        this.bccAddress = '';
        this.isSending = false;
        this.showEmailForm = false;
        this.cacheBuster = Date.now();
    }

    handleShowEmailForm() {
        this.showEmailForm = true;
    }

    handleBack() {
        this.showEmailForm = false;
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
        this.body = event.detail ? event.detail.value : event.target.value;
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
                this.showToast('Error', 'Failed to send email: ' +
                    (error.body && error.body.message ? error.body.message : 'Unknown error'), 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}