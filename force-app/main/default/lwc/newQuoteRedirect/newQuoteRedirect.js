import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class NewQuoteRedirect extends NavigationMixin(LightningElement) {
    @api recordId;

    connectedCallback() {
        // Close the quick action modal
        this.dispatchEvent(new CloseActionScreenEvent());

        // Navigate to the full-page Aura component
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: {
                componentName: 'c__newQuoteOverride'
            },
            state: {
                c__opportunityId: this.recordId
            }
        });
    }
}
