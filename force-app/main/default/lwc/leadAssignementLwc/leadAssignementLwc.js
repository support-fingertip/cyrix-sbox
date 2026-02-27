import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchLead from '@salesforce/apex/leadCmpController.fetchLead';
import leadAssignment from '@salesforce/apex/leadCmpController.leadAssignment';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LeadAssignementLwc extends LightningElement {
    @api recordId;
    @track regionRecord = {};
    @track subRegionRecord = {};
    @track subRegions = [];
    @track selectVal;
    @track leadOwnerId;
    @track subRegionVal;
    @track isLoading = false;
    
    selectOptions = [
        { label: '--None--', value: '' },
        { label: 'ASM Transfer', value: 'ASM Transfer' },
        { label: 'Sales Engineer Transfer', value: 'Sales Engineer Transfer' },
    ];
    
    @track subRegionOptions = [{ label: '--None--', value: '' }];

    // Use renderedCallback instead of connectedCallback
    renderedCallback() {
        // This ensures we only load when recordId is available
        if (this.recordId && !this.isLoading && !this.regionRecord.Id) {
            this.loadLeadData();
        }
    }

    // OR use a getter/setter for recordId
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.loadLeadData();
        }
    }
    
    get recordId() {
        return this._recordId;
    }

    loadLeadData() {
        // Check if recordId is available
        if (!this.recordId) {
            console.log('recordId is not available yet');
            return;
        }
        
        this.isLoading = true;
        console.log('Loading data for recordId:', this.recordId); // Debug log
        
        fetchLead({ leadId: this.recordId })
            .then(data => {
                if (data) {
                    console.log('Apex Response Data:', JSON.stringify(data)); // Debug log
                    
                    this.regionRecord = data.region || {};
                    this.subRegions = data.subRegions || [];
                    
                    console.log('regionRecord:', this.regionRecord); // Debug log
                    console.log('subRegions:', this.subRegions); // Debug log
                    
                    // Reset and populate subRegionOptions
                    this.subRegionOptions = [{ label: '--None--', value: '' }];
                    
                    if (this.subRegions && this.subRegions.length > 0) {
                        this.subRegions.forEach(element => {
                            this.subRegionOptions.push({
                                label: element.Name,
                                value: element.Id
                            });
                        });
                    }
                    
                    this.error = undefined;
                } else {
                    this.regionRecord = {};
                    console.log('No data returned from Apex');
                }
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error;
                this.regionRecord = {};
                this.subRegions = [];
                this.isLoading = false;

                console.error('Apex Error:', error); // Debug log
                
                const evt = new ShowToastEvent({
                    title: 'Error',
                    message: error.body?.message || error.message || 'Unknown error occurred',
                    variant: 'error',
                    mode: 'dismissible'
                });
                this.dispatchEvent(evt);
            });
    }

    get isSelectedASM() {
        if (this.selectVal == 'ASM Transfer')
            return true;
        else
            return false;
    }
    
    get isSelectedSalesExe() {
        if (this.selectVal == 'Sales Engineer Transfer')
            return true;
        else
            return false;
    }

    get isManagerUser() {
        if (this.subRegionRecord && this.subRegionRecord.ASM__c != null)
            return true;
        else
            return false;
    }
    
    get isSalesExe() {
        if (this.subRegionRecord && this.subRegionRecord.Sales_Engineer__c != null)
            return true;
        else
            return false;
    }

    get isEnableSubmit() {
        if (this.selectVal != '' && this.selectVal != null && this.regionRecord && this.regionRecord.Id) {
            if (this.selectVal == 'ASM Transfer' && this.isManagerUser) {
                return false;
            } else if (this.selectVal == 'Sales Engineer Transfer' && this.isSalesExe) {
                return false;
            } else {
                return true;
            }
        } else {
            return true;
        }
    }

    handleChange(event) {
        this.selectVal = event.detail.value;
        if (this.selectVal == 'ASM Transfer' && this.isManagerUser) {
            this.leadOwnerId = this.subRegionRecord.ASM__c;
        } else if (this.selectVal == 'Sales Engineer Transfer' && this.isSalesExe) {
            this.leadOwnerId = this.subRegionRecord.Sales_Engineer__c;
        } else {
            this.leadOwnerId = null;
        }
    }
    
    handleSubRegion(event) {
        try {
            this.subRegionVal = event.detail.value;
            this.subRegionRecord = this.subRegions.find(subRegion => subRegion.Id === this.subRegionVal);
        } catch (e) {
            console.error('Error in handleSubRegion' + e);
        }
    }

    doSubmit(event) {
        leadAssignment({ 
            leadOwnerId: this.leadOwnerId, 
            leadId: this.recordId 
        })
            .then(result => {
                const evt = new ShowToastEvent({
                    title: 'Lead Assignment',
                    message: 'Lead Assignment is successful ',
                    variant: 'success',
                    mode: 'dismissible'
                });
                this.dispatchEvent(evt);
                
                // Refresh data after successful save
                this.loadLeadData();
                
                // Reset form values
                this.selectVal = '';
                this.subRegionVal = '';
                this.subRegionRecord = {};
                this.leadOwnerId = null;
                
                this.closeModel();
            })
            .catch(error => {
                this.error = error;
             /*   const evt = new ShowToastEvent({
                    title: 'Error ',
                    message: error.body.message,
                    variant: 'error',
                    mode: 'dismissible'
                });
                this.dispatchEvent(evt);
                */
            });
    }

    get isSubRegion() {
        if (this.subRegionVal != null)
            return true;
        else
            return false;
    }

    get isregionRecord() {
        // Check if regionRecord has data
        if (this.regionRecord && Object.keys(this.regionRecord).length > 0)
            return true;
        else
            return false;
    }
    
    closeModel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}