import { LightningElement,api } from 'lwc';

export default class NewCampaign extends LightningElement {
      @api recordId;


        closeModal() {

    // Navigate to the Campaign object home
    this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
            objectApiName: 'Campaign',
            actionName: 'home'
        }
    });
}

}