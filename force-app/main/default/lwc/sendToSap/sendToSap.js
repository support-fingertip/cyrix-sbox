/**
 * Send to SAP — headless quick action on Account and Order.
 * Calls SAPsend_TriggerHandler.SendToSAP_call(recordId), which fires
 * the @Future SAP callout in the background. Shows a toast based on
 * the integer status code returned synchronously.
 *
 *   1 = send request submitted          -> success toast
 *   2 = already sent / no-op            -> info toast
 *   anything else                       -> error toast
 */
import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendToSapCall from '@salesforce/apex/SAPsend_TriggerHandler.SendToSAP_call';

export default class SendToSap extends LightningElement {
    @api recordId;
    @api objectApiName;

    @api invoke() {
        sendToSapCall({ recordId: this.recordId })
            .then(status => {
                this.handleStatus(status);
            })
            .catch(error => {
                const msg = error && error.body && error.body.message
                    ? error.body.message
                    : 'Failed to send to SAP';
                this.showToast('Error', msg, 'error');
            });
    }

    handleStatus(status) {
        const isAccount = this.objectApiName === 'Account';
        const entityLabel = isAccount ? 'Customer' : 'Order';

        if (status === 1) {
            this.showToast('Success', `${entityLabel} sent successfully`, 'success');
        } else if (status === 2) {
            this.showToast(
                'Info',
                `${entityLabel} is already marked as sent to SAP`,
                'info'
            );
        } else {
            this.showToast(
                'Error',
                `Could not send ${entityLabel.toLowerCase()} to SAP`,
                'error'
            );
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
