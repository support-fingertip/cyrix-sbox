import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import handleDocumentUpload from '@salesforce/apex/OpportunityDocUploadController.handleDocumentUpload';
import renameUploadedFile from '@salesforce/apex/OpportunityDocUploadController.renameUploadedFile';
import getDocumentStatus from '@salesforce/apex/OpportunityDocUploadController.getDocumentStatus';

const DOC_TYPES = ['WO', 'PO', 'Cheque', 'DD', 'Cash', 'UPI'];

export default class OpportunityDocUpload extends LightningElement {
    @api recordId;
    @track selectedDocType = '';
    @track docStatus = {};
    @track isLoading = false;

    wiredStatusResult;

    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx', '.xls', '.xlsx'];

    get documentTypeOptions() {
        return DOC_TYPES.map(type => ({ label: type, value: type }));
    }

    get uploadLabel() {
        return this.selectedDocType ? `Upload ${this.selectedDocType} Document` : 'Upload Document';
    }

    get docStatusList() {
        return DOC_TYPES.map(type => {
            const uploaded = this.docStatus[type] || false;
            return {
                type,
                uploaded,
                statusText: uploaded ? 'Uploaded' : 'Pending',
                iconName: uploaded ? 'utility:success' : 'utility:clock',
                statusClass: uploaded ? 'slds-text-color_success' : 'slds-text-color_weak'
            };
        });
    }

    @wire(getDocumentStatus, { opportunityId: '$recordId' })
    wiredStatus(result) {
        this.wiredStatusResult = result;
        if (result.data) {
            this.docStatus = { ...result.data };
        }
    }

    handleDocTypeChange(event) {
        this.selectedDocType = event.detail.value;
    }

    async handleUploadFinished(event) {
        this.isLoading = true;
        const uploadedFiles = event.detail.files;

        try {
            // Rename file with document type + date
            await renameUploadedFile({
                opportunityId: this.recordId,
                documentType: this.selectedDocType
            });

            // Check the respective checkbox
            await handleDocumentUpload({
                opportunityId: this.recordId,
                documentType: this.selectedDocType
            });

            // Refresh status
            await refreshApex(this.wiredStatusResult);

            this.showToast(
                'Success',
                `${this.selectedDocType} document uploaded successfully.`,
                'success'
            );
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Upload processing failed.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
