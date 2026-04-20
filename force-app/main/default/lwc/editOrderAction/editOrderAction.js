import { LightningElement, api } from 'lwc';
import getOrderDetails from '@salesforce/apex/CreateSalesOrderController.getOrderDetails';

export default class EditOrderAction extends LightningElement {
    @api recordId;
    loaded = false;
    errorMsg = '';
    orderNumber = '';

    connectedCallback() {
        if (this.recordId) {
            getOrderDetails({ orderId: this.recordId })
                .then(data => {
                    this.orderNumber = data.quoteNumber || 'OK';
                    this.loaded = true;
                })
                .catch(err => {
                    this.errorMsg = err.body ? err.body.message : JSON.stringify(err);
                    this.loaded = true;
                });
        } else {
            this.errorMsg = 'No recordId received';
            this.loaded = true;
        }
    }
}