import { LightningElement, api, track, wire } from 'lwc';
import duplicateLeads from '@salesforce/apex/LeadMergeController.duplicateLeads';
import fetchLeads from '@salesforce/apex/LeadMergeController.fetchLeads';
import mergeLeadsApex from '@salesforce/apex/LeadMergeController.mergeLeads';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class LeadMergeLwc extends NavigationMixin(LightningElement) {
    @api recordId;
    @track step = 1;
    @track duplicateLeads = [];
    @track selectedLeadIds = [];
    @track fields = [];
    @track firstLead;
    @track secondLead;
    @track selectedFields = {};

    columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email' },
        { label: 'Phone', fieldName: 'Phone' }
    ];

    get isStep1() {
        return this.step === 1;
    }

    get isStep2() {
        return this.step === 2;
    }

    get isNextDisabled() {
        return this.selectedLeadIds.length !== 1;
    }

    @wire(duplicateLeads, { leadId: '$recordId' })
    leadData({ error, data }) {
        if (data) {
            this.duplicateLeads = data;
        } else if (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error.body.message,
                variant: 'error'
            }));
        }
    }

    handleSelection(event) {
        this.selectedLeadIds = event.detail.selectedRows.map(row => row.Id);
    }

    loadComparison() {
        fetchLeads({
            firstLeadId: this.recordId,
            secondLeadId: this.selectedLeadIds[0]
        })
            .then(result => {
                this.firstLead = result.firstLead;
                this.secondLead = result.secondLead;

                this.fields = result.fieldset.map(f => {
                    const selectable = f.label !== 'Lead CreatedDate' && f.label !== 'Last ModifiedDate';
                    return {
                        ...f,
                        selectable,
                        checked1: selectable ? true : false,
                        checked2: false
                    };
                });

                this.fields.forEach(f => {
                    if (f.selectable) {
                        this.selectedFields[f.label] = f.value1;
                    }
                });

                this.step = 2;
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error loading comparison',
                    message: error.body.message,
                    variant: 'error'
                }));
            });
    }

    handleFieldChoice(event) {
        const fieldLabel = event.target.name;
        const choice = event.target.value;

        this.fields = this.fields.map(f => {
            if (f.label === fieldLabel) {
                return {
                    ...f,
                    checked1: choice === 'lead1',
                    checked2: choice === 'lead2'
                };
            }
            return f;
        });

        const selectedField = this.fields.find(f => f.label === fieldLabel);
        this.selectedFields[fieldLabel] = choice === 'lead1' ? selectedField.value1 : selectedField.value2;
    }

    selectAllLead1() {
        this.fields = this.fields.map(f => {
            if (f.selectable) {
                this.selectedFields[f.label] = f.value1;
                return { ...f, checked1: true, checked2: false };
            }
            return f;
        });
    }

    selectAllLead2() {
        this.fields = this.fields.map(f => {
            if (f.selectable) {
                this.selectedFields[f.label] = f.value2;
                return { ...f, checked1: false, checked2: true };
            }
            return f;
        });
    }

    mergeLeads() {
        mergeLeadsApex({
            firstLead: this.firstLead,
            secondLead: this.secondLead,
            selectedFields: this.selectedFields
        })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Leads merged successfully!',
                    variant: 'success'
                }));
                 // Redirect to the merged Lead record detail page
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: result, // assuming Apex returns the merged Lead Id
                        objectApiName: 'Lead',
                        actionName: 'view'
                    }
                });
            })
           .catch(error => {
    console.error('Merge error:', JSON.stringify(error));

    let errorMessage = 'An unknown error occurred';

    if (error?.body?.message) {
        errorMessage = error.body.message;
    } else if (error?.body?.pageErrors?.length > 0) {
        errorMessage = error.body.pageErrors.map(e => e.message).join(', ');
    } else if (error?.body?.fieldErrors) {
        // Handle field-specific errors
        const fieldErrors = Object.values(error.body.fieldErrors)
            .flat()
            .map(e => e.message);
        errorMessage = fieldErrors.join(', ');
    } else if (error?.message) {
        errorMessage = error.message;
    }

    this.dispatchEvent(new ShowToastEvent({
        title: 'Merge failed',
        message: errorMessage,
        variant: 'error'
    }));
});

   

     
    }

    closeModel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}