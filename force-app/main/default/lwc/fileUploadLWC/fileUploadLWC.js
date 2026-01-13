import { LightningElement, api, track } from 'lwc';
import getFiles from '@salesforce/apex/LightningFileUploadHandler1.getFiles';
import deleteFile from '@salesforce/apex/LightningFileUploadHandler1.deleteFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class FileUploadLWC extends NavigationMixin(LightningElement) {
    @api recordId;
    @api showdelete;
    @api uniqueId;
    @api isRequired;
    @api label;
    @track files = [];
    @track showSpinner = false;
    @api acceptFileTypes = ['.jpg', '.jpeg', '.png'];
    @api uploadMultiple = false;
    isLoading = false;
    showFiles = false;

    connectedCallback() {
        this.loadFiles('OnLoad');
    }

    get uploadClass() {
        if (this.isRequired && !this.showFiles && !this.isLoading) {
            return 'slds-text-align_center slds-box error-border';
        }
        return 'slds-text-align_center slds-box';
    }
    loadFiles(operation) {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
        this.isLoading = true;
        getFiles({ recordId: this.recordId,uniqueId : this.uniqueId,operation:operation })
        .then(result => {
            this.files = result;
            this.showFiles = result.length > 0 ? true : false;
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error fetching files:', error);
        });
    }

    handleUploadFinished() {
        this.loadFiles('OnUpload');
        this.showToast('Success', 'File uploaded successfully!', 'success');
    }

    previewFile(event) {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
        let recordId = event.target.dataset.id;
        const recordId2 = event.currentTarget.dataset.id;
        console.log('recId'+recordId);
        console.log('recId2'+recordId2);
        //  const filetype = event.currentTarget.id
          this[NavigationMixin.Navigate]({
              type: 'standard__namedPage',
              attributes: {
                  pageName: 'filePreview'
              },
              state: {
                  selectedRecordId: recordId
              }
          });


    }

    deleteFile(event) {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
        if (confirm('Confirm deleting this file?')) {
            this.showSpinner = true;
            let fileId = event.currentTarget.dataset.id;
            deleteFile({ contentDocumentId: fileId })
                .then(() => {
                    this.loadFiles();
                    this.showSpinner = false;
                    this.showToast('Success', 'File has been deleted successfully!', 'success');
                })
                .catch(error => {
                    this.showSpinner = false;
                    console.error('Error deleting file:', error);
                });
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}