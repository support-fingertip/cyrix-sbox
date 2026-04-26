/**
 * Send to SAP — headless quick action on Account and Order.
 * Calls SapSyncController.sendToSap with the current record id and
 * shows a success / error toast. No UI is rendered.
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendToSap from '@salesforce/apex/SapSyncController.sendToSap';

export default class SendToSap extends LightningElement {
    @api recordId;
    @api objectApiName;

    @api invoke() {
        sendToSap({ recordId: this.recordId })
            .then(result => {
                if (result && result.startsWith('ERROR:')) {
                    this.showToast('Error', result.replace('ERROR:', '').trim(), 'error');
                } else {
                    this.showToast('Success', result, 'success');
                }
            })
            .catch(error => {
                const msg = error && error.body && error.body.message
                    ? error.body.message
                    : 'Failed to send to SAP';
                this.showToast('Error', msg, 'error');
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
