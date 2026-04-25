// Send Order Email — Order quick action LWC.
// Calls OrderPDFEmailController.sendOrderEmail to send + log the email.
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import sendOrderEmail from '@salesforce/apex/OrderPDFEmailController.sendOrderEmail';

// Send Order Email — Order quick action.

import ORDER_NAME from '@salesforce/schema/Order.Name';
import ORDER_NUMBER from '@salesforce/schema/Order.OrderNumber';
import ORDER_OWNER_ID from '@salesforce/schema/Order.OwnerId';
import ACCOUNT_NAME from '@salesforce/schema/Order.Account.Name';
import BILLTO_NAME from '@salesforce/schema/Order.BillToContact.Name';
import BILLTO_EMAIL from '@salesforce/schema/Order.BillToContact.Email';
import OPPORTUNITY_NAME from '@salesforce/schema/Order.Opportunity.Name';
import OPPORTUNITY_EMAIL from '@salesforce/schema/Order.Opportunity.Email__c';

import USER_NAME from '@salesforce/schema/User.Name';
import USER_EMAIL from '@salesforce/schema/User.Email';
import USER_TITLE from '@salesforce/schema/User.Title';

const ORDER_FIELDS = [
    ORDER_NAME, ORDER_NUMBER, ORDER_OWNER_ID,
    ACCOUNT_NAME,
    BILLTO_NAME, BILLTO_EMAIL,
    OPPORTUNITY_NAME, OPPORTUNITY_EMAIL
];

const USER_FIELDS = [USER_NAME, USER_EMAIL, USER_TITLE];

export default class SendOrderPDF extends LightningElement {
    @api recordId;

    toAddress = '';
    ccAddress = '';
    bccAddress = '';
    subject = '';
    body = '';
    isSending = false;

    _orderName = '';
    _orderNumber = '';
    _accountName = '';
    _contactName = '';
    _contactEmail = '';
    _opportunityName = '';
    _opportunityEmail = '';
    _ownerId = null;

    _ownerName = '';
    _ownerEmail = '';
    _ownerTitle = '';

    richTextFormats = [
        'font', 'size', 'bold', 'italic', 'underline', 'strike',
        'list', 'indent', 'align', 'link', 'clean', 'color', 'background',
        'header', 'direction'
    ];

    @wire(getRecord, { recordId: '$recordId', fields: ORDER_FIELDS })
    wiredOrder({ data, error }) {
        if (data) {
            this._orderName = getFieldValue(data, ORDER_NAME) || '';
            this._orderNumber = getFieldValue(data, ORDER_NUMBER) || '';
            this._accountName = getFieldValue(data, ACCOUNT_NAME) || '';
            this._contactName = getFieldValue(data, BILLTO_NAME) || '';
            this._contactEmail = getFieldValue(data, BILLTO_EMAIL) || '';
            this._opportunityName = getFieldValue(data, OPPORTUNITY_NAME) || '';
            this._opportunityEmail = getFieldValue(data, OPPORTUNITY_EMAIL) || '';
            this._ownerId = getFieldValue(data, ORDER_OWNER_ID) || null;
            this.buildDefaults();
        } else if (error) {
            this.showToast('Error', 'Failed to load order: ' +
                (error.body && error.body.message ? error.body.message : 'Unknown error'), 'error');
        }
    }

    @wire(getRecord, { recordId: '$_ownerId', fields: USER_FIELDS })
    wiredOwner({ data, error }) {
        if (data) {
            this._ownerName = getFieldValue(data, USER_NAME) || '';
            this._ownerEmail = getFieldValue(data, USER_EMAIL) || '';
            this._ownerTitle = getFieldValue(data, USER_TITLE) || '';
            this.buildDefaults();
        } else if (error) {
            this._ownerName = '';
            this._ownerEmail = '';
            this._ownerTitle = '';
        }
    }

    buildDefaults() {
        this.toAddress = this._opportunityEmail || this._contactEmail || this._ownerEmail || '';

        const orderRef = this._orderNumber || this._orderName;
        const contextName = this._opportunityName || this._accountName || '';
        if (orderRef && contextName) {
            this.subject = 'Order ' + orderRef + ' - ' + contextName;
        } else if (orderRef) {
            this.subject = 'Order ' + orderRef;
        } else {
            this.subject = '';
        }

        const greetingName = this._contactName || this._accountName || 'Sir/Madam';
        const projectName = this._opportunityName || this._orderName;
        const signatureTitle = this._ownerTitle ? '<br/>' + this._ownerTitle : '';

        this.body =
            '<p>Dear ' + greetingName + ',</p>' +
            '<p>I hope this email finds you well.</p>' +
            '<p>This is regarding the order ' + projectName + '.</p>' +
            '<p>Best regards,</p>' +
            '<p><strong>For Cyrix Healthcare Pvt. Ltd</strong></p>' +
            '<p>' + this._ownerName + signatureTitle + '</p>';
    }

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

        sendOrderEmail({
            orderId: this.recordId,
            toAddress: this.toAddress,
            ccAddress: this.ccAddress,
            bccAddress: this.bccAddress,
            subject: this.subject,
            body: this.body
        })
            .then(result => {
                this.isSending = false;
                if (result === 'SUCCESS') {
                    this.showToast('Success', 'Order email sent successfully!', 'success');
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
