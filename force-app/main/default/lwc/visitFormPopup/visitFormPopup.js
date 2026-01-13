import { LightningElement, api, track, wire } from 'lwc';
import VisitData from '@salesforce/apex/visitManager.getVisitCreateData';
import { createRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getPicklistValues, getObjectInfo } from 'lightning/uiObjectInfoApi';
import getFiles from '@salesforce/apex/visitManager.getFiles';
import FORM_FACTOR from '@salesforce/client/formFactor';
import deleteFile from '@salesforce/apex/visitManager.deleteFile';
//fields
import VISIT_OBJECT from '@salesforce/schema/Visit__c';
import VISIT_FOR_FIELD from '@salesforce/schema/Visit__c.Visit_for__c';
import VISIT_TYPE_FIELD from '@salesforce/schema/Visit__c.Visit_Type__c';
import VISIT_PURPOSE_FIELD from '@salesforce/schema/Visit__c.Visit_Purpose__c';
import VISIT_FEEDBACK_FIELD from '@salesforce/schema/Visit__c.Visit_Feedback__c';



export default class visitformpopup extends LightningElement {


    isSearchValueSelected = false; searchPlaceHolder; searchLabel; isValueSearched = false; searchValueName = '';
    headerVisit = '';

    @api recordId;
    @api visitOutletData;
    @api completeVisit;
    pickData; isOthereVisit = false;
    pickData1;
    pickDatapurpose;
    pickDataFeedback;
    @wire(getObjectInfo, { objectApiName: VISIT_OBJECT })
    visitInfo;
    @api newVisitCreate;
    @api reshedule;


    @api dailyLogId;
    @api isDesktop;


    isPhone = false;
    @track isCameraOpen = true;
    showUploadedFiles = false;
    @track uploadedFiles = [];
    @track showCameraModal = false;

    @track showCameraModal = false;
    isPhotoTaken = false;
    @track objData = {
        Lead: [],
        Customer: [],
        searchItems: [],
        searchNameData: []
    }
    containerClass;

     @api isDisabled = false;

    @api setDisabled(val) {
        this.isDisabled = val;
    }
 get modalClass() {
      
        // Fullscreen on mobile/tablet, normal modal on desktop
        return `slds-modal slds-fade-in-open  ${this.isDesktop? '' : ' slds-modal_full'}`;
    }
get searchNameData() {
    return this.objData.searchNameData.map(item => ({
        ...item,
        icon: this.isCustomer ? 'standard:account' : 'standard:lead',
        subText: this.isCustomer ? item.Phone : `Mob: ${item.MobilePhone}`
    }));
}


    @wire(getPicklistValues, {
        recordTypeId: '$visitInfo.data.defaultRecordTypeId',
        fieldApiName: VISIT_FOR_FIELD
    })
    visitforPicklistValue({ error, data }) {
        if (data) {
            this.pickData = [
                ...data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }))
            ];
        } else if (error) {
            console.error('Error fetching Zone picklist values:', error);
        }
    };

    @wire(getPicklistValues, {
        recordTypeId: '$visitInfo.data.defaultRecordTypeId',
        fieldApiName: VISIT_TYPE_FIELD
    })
    visittypePicklistValue({ error, data }) {
        if (data) {
            this.pickData1 = [
                ...data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }))
            ];
        } else if (error) {
            console.error('Error fetching Zone picklist values:', error);
        }
    };

    @wire(getPicklistValues, {
        recordTypeId: '$visitInfo.data.defaultRecordTypeId',
        fieldApiName: VISIT_PURPOSE_FIELD
    })
    visitpurposePicklistValue({ error, data }) {
        if (data) {
            this.pickDatapurpose = [
                ...data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }))
            ];
        } else if (error) {
            console.error('Error fetching purpose picklist values:', error);
        }
    };


    @wire(getPicklistValues, {
        recordTypeId: '$visitInfo.data.defaultRecordTypeId',
        fieldApiName: VISIT_FEEDBACK_FIELD
    })
    visitFeedbackPicklistValue({ error, data }) {
        if (data) {
            this.pickDataFeedback = [
                ...data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }))
            ];
        } else if (error) {
            console.error('Error fetching purpose picklist values:', error);
        }
    };








    @track visitData = {
        //   Name : 'v',
        Visit_for__c: 'Lead',
        Status__c: 'Planned',
        Lead__c: '',
        Visit_Type__c: '',
        Account__c: '',
        Daily_Log__c: '',
        Comments__c: '',
        //  Other_Visit__c  : '',
        PostPoned_Start_Time__c: null,
        Missed_PostPone_Reason__c: '',
        // Approval_Status__c : 'Approved',
        Visit_Date__c: this.getDateValues(),
        Planned_Start_Time__c: this.getDateValues()
    };





    connectedCallback() {
        if (this.newVisitCreate) {
            this.headerVisit = 'Create New Visit';
            this.getVisitData();
        }
        else if (this.reshedule) {
            this.headerVisit = 'Missed Visit';
        }
        else if (this.completeVisit) {
            this.headerVisit = 'Complete Visit';

        }
  this.isDesktop = FORM_FACTOR === 'Large';
this.isPhone = FORM_FACTOR === 'Small';
//this.containerClass = this.isDesktop ? 'slds-modal__container' : '';
        this.loadAllFiles();
    }

handleEnable(e) {
    this.isDisabled = e.detail.isDisabled;

}

    getDateValues() {
        const now = new Date();
        return now.toISOString();

    }

    getVisitData() {

        VisitData({})
            .then(result => {
                this.objData.Lead = result.lead;
                this.objData.Customer = result.Customer;
                this.objData.searchItems = this.objData.Lead;
                this.isSearchValueSelected = true;
                this.searchPlaceHolder = 'Search Lead....';
                this.searchLabel = 'Lead';
            })
            .catch(error => {
                console.error(error);
            });
    }

    closeVisit() {

        const event = new CustomEvent('myvisitclick', {
            detail: { message: 'Close' }
        });
        // Dispatches the event.

        this.dispatchEvent(event);
    }
    genericDispatchEvent(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    saveVisit() {
        if (this.completeVisit) {
            if (this.visitData.Comments__c == '') {
                const warningMsg = 'Please enter Comments';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            }
            if (!this.isPhotoTaken) {
                const warningMsg = 'Please take photo';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            }
            this.isDisabled = true;
            const message = new CustomEvent('myvisitclick', {
                detail: {
                    message: 'createNewVisit',
                    Comment: this.visitData.Comments__c,
                    feedback: this.visitData.Visit_Feedback__c
                }
            });
            this.dispatchEvent(message);
        } else if (this.newVisitCreate) {
            if (this.visitData.Visit_for__c == '') {
                const warningMsg = 'Please select visit for';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            } else if (this.visitData.Visit_for__c == 'Lead' && this.visitData.Lead__c == '') {
                const warningMsg = 'Please select Lead';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            } else if (this.Visit_for__c == 'Customer' && this.visitData.Account__c == '') {
                const warningMsg = 'Please select Customer';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            } else if (this.visitData.Visit_for__c == '' || this.visitData.Visit_for__c == undefined) {
                const warningMsg = 'Please select visit for';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            }
            else if (this.visitData.Visit_Purpose__c == '' || this.visitData.Visit_Purpose__c == undefined) {
                const warningMsg = 'Please select visit Purpose';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            }
            else if (this.visitData.Visit_Type__c == '' || this.visitData.Visit_Type__c == undefined) {
                const warningMsg = 'Please select visit type';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            } else if (this.visitData.Visit_Date__c == null || this.visitData.Visit_Date__c == undefined) {
                const warningMsg = 'Please select a Visit date';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            } else if (this.visitData.Visit_Date__c != null && this.visitData.Visit_Date__c != undefined) {
                this.creatingNewVisit();
            }

        }
        else if (this.reshedule) {
            if (this.visitData.Missed_PostPone_Reason__c == '') {
                const warningMsg = 'Please enter missed reason';
                this.genericDispatchEvent('Warning', warningMsg, 'warning');
                return;
            }
            else if (this.visitData.PostPoned_Start_Time__c == undefined || this.visitData.PostPoned_Start_Time__c == '') {
                const msg = "Add a Visit date";
                const title = ''
                const variant = 'warning';
                this.genericDispatchEvent(title, msg, variant);
                return;
            }
            this.isDisabled = true;
            const message = new CustomEvent('myvisitclick', {
                detail: {
                    message: 'missedReason',
                    missedReason: this.visitData.Missed_PostPone_Reason__c,
                    missedDate: this.visitData.PostPoned_Start_Time__c,
                }
            });
            this.dispatchEvent(message);
        }
    }
    handleOnBlur() {
        setTimeout(() => {
            this.isValueSearched = false;
        }, 1000);
    }

    //Method to create new visit
    creatingNewVisit() {
        try {
            var leadId = this.visitData.Lead__c;
            var accId = this.visitData.Account__c;
            var vDate = new Date(this.visitData.Visit_Date__c).toLocaleDateString('en-GB');
            const fields = this.visitData;

            const duplicatePlanned = this.visitOutletData.some(v => ((v.acccountId === accId) || (v.acccountId === leadId))
                && (v.formattedVisitDate === vDate) && (v.status === 'Planned'));

            if (duplicatePlanned) {
                this.genericDispatchEvent(
                    'Duplicate Visit',
                    'A visit is already planned for this customer/lead on this date.',
                    'error'
                );

                return;

            }

            this.isDisabled = true;

            const recordInput = { apiName: VISIT_OBJECT.objectApiName, fields };
            createRecord(recordInput)
                .then((result) => {
                    const event = new CustomEvent('myvisitclick', {
                        detail: { message: 'Save' }
                    });
                    // Dispatches the event.
                    this.isDisabled = false;
                    this.dispatchEvent(event);

                })
                .catch((error) => {
                    // Handle error in record creation
                    const event = new CustomEvent('myvisitclick', {
                        detail: { message: 'Save', error: error }
                    });
                    // Dispatches the event.
                    this.isDisabled = false;
                    this.dispatchEvent(event);
                    console.error('Error creating record:', error);
                });
        }
        catch (error) {
            console.error('error' + error.message);
        }

    }
    resetData() {
        this.searchValueName = '';
        this.Other_Visit__c = '';
        this.isValueSearched = false;
        this.visitData.Account__c = '';
        this.visitData.Lead__c = '';
        this.isOthereVisit = false;
        this.isSearchValueSelected = false;
    }
    onCommentChange(event) {
        this.visitData[event.currentTarget.name] = event.detail.value;
        const fieldTarget = event.currentTarget.name;
        const fieldValue = event.detail.value;
        if (fieldTarget === 'PostPoned_Start_Time__c' && fieldValue) {
            const enteredDateTime = new Date(fieldValue);
            const now = new Date();

            if (enteredDateTime < now) {
                const nowPlusOneMinute = new Date(now.getTime() - 60 * 1000);
                if (enteredDateTime.getTime() < nowPlusOneMinute.getTime()) {
                    this.visitData.PostPoned_Start_Time__c = null;
                    const msg = "Select a future date";
                    const title = ''
                    const variant = 'warning';
                    this.genericDispatchEvent(title, msg, variant);
                    return;
                }
            }
        }
    }
    handleVisitType(event) {
        this.visitData.Visit_Type__c = event.detail.value;
    }
    handleVisitPurpose(event) {
        this.visitData.Visit_Purpose__c = event.detail.value;
    }
    handleVisitFeedback(event) {
        this.visitData.Visit_Feedback__c = event.detail.value;
    }

    handleChange(event) {
        this.visitData[event.currentTarget.name] = event.detail.value;
        if (event.currentTarget.name === "Visit_for__c") {

            this.resetData();
            if (event.detail.value == 'Lead') {
                this.objData.searchItems = this.objData.Lead;
                this.isSearchValueSelected = true;
                this.searchPlaceHolder = 'Search Lead....';
                this.searchLabel = 'Lead';
            }
            else if (event.detail.value == 'Customer') {

                this.objData.searchItems = this.objData.Customer;
                this.isSearchValueSelected = true;
                this.searchPlaceHolder = 'Search Customer....';
                this.searchLabel = 'Customer';
            }


        }


        const fieldTarget = event.currentTarget.name;
        const fieldValue = event.detail.value;

        if (fieldTarget === 'Visit_Date__c' && fieldValue) {
            const enteredDateTime = new Date(fieldValue);
            const now = new Date();
            const nowPlusOneMinute = new Date(now.getTime() - 60 * 1000);

            if (enteredDateTime < now) {
                if (enteredDateTime.getTime() < nowPlusOneMinute.getTime()) {
                    this.visitData.Visit_Date__c = null;
                    const msg = "Select a future date";
                    const title = ''
                    const variant = 'warning';
                    this.genericDispatchEvent(title, msg, variant);
                    return;
                }
            }
        }

    }
    handleSearch(event) {
        this.searchValueName = event.target.value;
        // console.log(userName);
        if (this.searchValueName) {
            this.searchText();
        } else {
            this.isValueSearched = false;
            this.visitData.Account__c = '';
            this.visitData.Lead__c = '';
        }

    }

    searchText() {
        let objData = this.objData.searchItems;
        let storeData = [];
        for (let i = 0; i < objData.length; i++) {
            const objName = objData[i];
            if ((objName.Name && objName.Name.toLowerCase().indexOf(this.searchValueName.toLowerCase()) !== -1)) {
                storeData.push(objName);
            }
        }
        this.isValueSearched = storeData != 0 ? true : false;
        this.objData.searchNameData = storeData;
        console.log('objData>>' + JSON.stringify(objData));
    }
    get isCustomer() {
        return this.visitData.Visit_for__c === 'Customer';
    }
    selectObjName(event) {
        const apiFieldName = this.visitData.Visit_for__c;
        if (apiFieldName == 'Lead') {
            this.visitData.Lead__c = event.currentTarget.dataset.id;
        }
        else if (apiFieldName == 'Customer') {
            this.visitData.Account__c = event.currentTarget.dataset.id;
        }
        this.searchValueName = event.currentTarget.dataset.name;
        this.isValueSearched = false;
    }
    handleOrderScreen(event) {
        const msg = event.detail;
        if (msg.message == 'camerScreen') {
            this.isPhotoTaken = msg.isPhotoTaken;
        }
    }
    //camera addedd
    openCamera() {
        this.showCameraModal = true;
    }
    handleCameraStopped() {
        this.showCameraModal = false;
        this.loadAllFiles();
    }
    handleUploadFinished(event) {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }

        const files = event.detail.files;
        if (files && files.length > 0) {
            this.isPhotoTaken = true;
            this.genericDispatchEvent('Success', 'Files uploaded successfully!', 'success');
            this.loadAllFiles();
            return;
            // this.showToast('Success', 'Files uploaded successfully!', 'success');
        }
    }
    loadAllFiles() {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
        this.isLoading = true;
        getFiles({ recordId: this.recordId })
            .then(result => {
                this.uploadedFiles = result || [];
                this.showUploadedFiles = this.uploadedFiles.length > 0;
                if (this.uploadedFiles.length > 0) {
                    this.isPhotoTaken = true;
                }
                else {
                    this.isPhotoTaken = false;
                }
            })
            .catch(error => {
                console.error('Error loading files:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    async deleteFile(event) {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
        if (confirm('Confirm deleting this file?')) {
            const fileId = event.currentTarget.dataset.id;
            this.isLoading = true;
            try {
                await deleteFile({ contentDocumentId: fileId });
                this.genericDispatchEvent('Success', 'File has been deleted successfully!', 'success');
                //this.genericDispatchToastEvent('Success','File has been deleted successfully!', 'Success');
                //   this.showToast('Success','File has been deleted successfully!', 'Success');
                this.loadAllFiles();
            } catch (err) {
                console.error('Delete error', err);
                this.showToast('Error', 'Deletion failed', 'error');
            }
            this.isLoading = false;
        }
    }

    previewFile(event) {
        let recordId1 = event.currentTarget.dataset.id;
        //  const filetype = event.currentTarget.id
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: recordId1
            }
        });


    }
}