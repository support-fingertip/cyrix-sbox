import { LightningElement,api,track } from 'lwc';
import getApexData from '@salesforce/apex/beatPlannerlwc.getData';
import getAllVisitData from '@salesforce/apex/beatPlannerlwc.getAllVisitData';
import { getLocationService } from 'lightning/mobileCapabilities';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { deleteRecord } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';
  

export default class ExecuteScreen extends NavigationMixin(LightningElement) {

    summeryIcons = {
        stock : GOOGLE_ICONS + "/googleIcons/stock.png",
        payment :  GOOGLE_ICONS + "/googleIcons/payment.png",
        camera :  GOOGLE_ICONS + "/googleIcons/camera.png",
        order :  GOOGLE_ICONS + "/googleIcons/order.png",
        task :  GOOGLE_ICONS + "/googleIcons/task.png",
        Competitor :  GOOGLE_ICONS + "/googleIcons/Competitor.png",
        summery :  GOOGLE_ICONS + "/googleIcons/summery.png",
    };

    openBusinessSummary = false;
    businessSummery = {
        totalOutStanding : 0,
        totalOrderAmt : 0,
        totalSalesAmt : 0,
        AllVisit : 0
    };
    @api recordId;
    @api index;
    @api accId;
    @api objName; 
    @api isProgressVisit;
    @api isInProgress;
    @api isAcc;
    @api isCompleted;
    @api isDesktop;
    
    @api dailyLogData;
    @api visitParentData;
    @api isplayButtonClicked = false;
    @track visitData = [];
    @track orderData = [];
    completeVisit = false;
    comment = null;
     feedback = null;
    isDesktopCheckoutPage = true;
    @track visActionData = {
        VisitPhoto : [],
        outletTask : [],
        paymentFollowUp:[],
        Competition : [],
        Stock : [],
        photoData : []
    };
    isImageDropdownOpen = false;
    dropdown = {
        camera : false,
        task : false,
        payment : false,
        stock : false,
        photo : false,
        competition : false,
        order : true,
        summery : true
    }
    tableHeading ={
        order:['Product Category','Product Name','Qnty','Amount'],
        //  stock:['Product Category','Product Name','Qnty','Amount'],
        payment : ['Name','Expected amt','Exp. Pay Date','Comments'],
        task:['Name','Desc.','Status'],
        comptitor:['Product Categ.','Product','Comp. Name','Disp. board','spl offer']
    } ;

    @api handleCheckOutVisit(){
        //this.isPageLoaded = true;
        this.isDesktopCheckoutPage = this.isDesktop ? true : false;
        this.completeVisit = true;
        //this.handleGetLatLon('checkout');
    }

    visitHeading = ['Visit','Account Name','Status','Actual Start date/time','Actual End date/time'];
    isPageLoaded = false;
    
    //detect if LWC is running in mobile publisher
    isMobilePublisher = window.navigator.userAgent.indexOf('CommunityHybridContainer') > 0;


    connectedCallback(){
        if(this.isProgressVisit != undefined && !this.isProgressVisit){
            if(this.visitParentData.status == 'Planned' && this.isplayButtonClicked){
                this.isPageLoaded = true;
                this.visActionData = {
                    VisitPhoto : null,
                    outletTask : null,
                    paymentFollowUp: null,
                    Competition : null,
                    Stock : null,
                    photoData : null
                }
                this.orderData = null;
                this.handleGetLatLon('checkin');
                //this.GetOrderDetailsData();
            }else{
                this.isPageLoaded = true;
                this.GetOrderDetailsData();
            }
        }
        else{
            this.isPageLoaded = true;
            this.GetOrderDetailsData();
        }
    }
    GetOrderDetailsData(){
        getAllVisitData({
            recordId: this.recordId,
        })
        .then(result => {
            console.log(result);
            this.orderData = result.orList ;
            this.visActionData.VisitPhoto = (result.VisitPhoto && result.VisitPhoto.length != 0) ? result.VisitPhoto : null;
            this.visActionData.outletTask = (result.outletTask && result.outletTask.length != 0 ) ? result.outletTask : null;
            this.visActionData.paymentFollowUp = (result.paymentFollowUp && result.paymentFollowUp.length != 0) ? result.paymentFollowUp : null;
            this.visActionData.Competition = (result.Competition && result.Competition.length != 0) ? result.Competition : null;
            this.visActionData.Stock =( result.Stock && result.Stock.length != 0) ? result.Stock : null;
            this.visActionData.photoData = (result.VisitPhoto && result.VisitPhoto.length != 0 )? result.VisitPhoto : null;
            this.isPageLoaded = false;
            this.businessSummery = {
                totalOutStanding : result.totalOutStanding,
                totalOrderAmt : result.totalOrderAmt,
                totalSalesAmt : result.totalSalesAmt,
                AllVisit : result.AllVisit
            };
        })
        .catch(error => {
            console.error(error);
            this.isPageLoaded = false;
        });
    }
    /*Getting geoLocation*/
    handleGetLatLon(checkOutIn) {
        console.log('this.isMobilePublisher: ' + this.isMobilePublisher);
        if(this.isMobilePublisher)
        {
            //invoke Location Service native mobile capability feature
            //to get current position
            getLocationService().getCurrentPosition({
            enableHighAccuracy: true
                }).then((result) => {

                    var newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse',{detail:{}});
                    newEvent.detail.lat = result.coords.latitude;
                    newEvent.detail.lon = result.coords.longitude; 
                    newEvent.detail.latlonsource = 'nimbus';
                    newEvent.detail.status = 'success';

                    console.log('newEvent: ' + JSON.stringify(newEvent));
                    this.handleSaveVisitData(newEvent,checkOutIn);

                }).catch((error) => {
                    console.log(JSON.stringify(error));
                    this.isPageLoaded = false;
                }).finally(() => {

                });

        }
        else if(window.navigator && window.navigator.geolocation)
        {
            //invoke browser native capability to get current position
            window.navigator.geolocation.getCurrentPosition((r,err) => {
                var newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse',{detail:{}});
                if(r && r.coords)
                {
                    
                    newEvent.detail.lat = r.coords.latitude;
                    newEvent.detail.lon = r.coords.longitude; 
                    newEvent.detail.latlonsource = 'browser';
                    newEvent.detail.status = 'success';
                    this.handleSaveVisitData(newEvent,checkOutIn);

                }
                else if(err)
                {
                  console.log(JSON.stringify(err));
                  this.isPageLoaded = false;
                }
            });
        
        }
        else 
        {
            console.log('Unable to get user location.');
            this.isPageLoaded = false;
        }
    }
    
    handleSaveVisitData(event,checkOutIn){
         if (!navigator.onLine) {
            this.genericDispatchToastEvent('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }
    let details = JSON.parse(JSON.stringify(event.detail));
    const now = new Date();
    const data = {
        Id: this.recordId,
        Comments__c : this.comment,
            Visit_Feedback__c : this.feedback,
            [checkOutIn === 'checkout' ? 'Check_Out_Location__Longitude__s' : 'Check_In_Location__Longitude__s']: details.lon,
            [checkOutIn === 'checkout' ? 'Check_Out_Location__Latitude__s' : 'Check_In_Location__Latitude__s']: details.lat,
            [checkOutIn === 'checkout' ? 'Visit_End__c' : 'Visit_Start__c']: now.toISOString(),
            Status__c: checkOutIn === 'checkout' ? 'Completed' : 'In Progress',
            Daily_Log__c: checkOutIn === 'checkout' ? this.dailyLogData.Id : this.dailyLogData.Id
        };
 
        
        const recordInput= {
            fields : data
        };
        this.saveUpdateRecord(recordInput,checkOutIn);
    }

    saveUpdateRecord(recordInput,checkOutIn){
        updateRecord(recordInput)
            .then((result) => {
                this.completeVisit = false;
                this.visitData = [result];
                var msg = checkOutIn === 'checkout' ? 'Visit Ended successfully' : 'Visit Started successfully';
                this.genericDispatchToastEvent('Success',msg,'success');
                this.isPageLoaded = false;
                
                if(checkOutIn == 'checkout'){
                    this.isDesktopCheckoutPage = true;
                    const event = new CustomEvent('screen3', {
                        detail: {message:'checkout'}
                    });
                    // if(checkOutIn == 'checkin'){
                    //     this.isPageLoaded = true;
                    //     this.GetOrderDetailsData();
                    // }
                    // Dispatching the event
                    this.dispatchEvent(event);
                    
                }
                if(checkOutIn == 'checkin'){
                    this.isPageLoaded = true;
                    this.GetOrderDetailsData();
                }
               // this.setDataResult(result, toastMessage);                    
            })
            .catch((error) => {
                // Handle error in record creation
                this.isDailyLog = false;
                this.isPageLoaded = false;
                console.error('Error creating record:', error);
            });
    }

    formatDate(date) {
        const year = date.getFullYear();
        const month = (date.getMonth() + 1).toString().padStart(2, '0'); // Month starts from 0
        const day = date.getDate().toString().padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    getTheDateBackend(obj,dateValue,selectedDate) {

        let todayDate =this.formatDate(new Date());
        
        //this.isSpinner = true;
        getApexData({ 
            isoffSet: null,
            isLimit: null,
            objName : 'BeatPlan',
            fromDate : todayDate,
            toDate : todayDate
        })
        .then(result => {
            console.log(result);

            this.visitData = result.visit;
   
        })
        .catch(error => {
            console.error(error);
            //this.isSpinner = false;
        });
    }

    openCamerScreen() {
        const  message = { 
         message: 'cameraScreen' ,
         recordID : this.recordId,
         index : this.index,
         screen : 3.2
        };
        this.genericDispatchEvent(message);
    }

    openProductScreen() {
            const  message = { 
             message: 'productScreen' ,
             recordID : this.recordId,
             index : this.index,
             screen : 3.2
         };
            this.genericDispatchEvent(message);
    }
    openStockScreen() {
        const  message = { 
         message: 'StockSCreen' ,
         recordID : this.recordId,
         index : this.index,
         screen : 3.2
     };
        this.genericDispatchEvent(message);
}
    openTaskScreen(){
        const  message = { 
            message: 'taskScreen' ,
            recordID : this.recordId,
            index : this.index,
            screen : 3.4,
            accId : this.accID,
            objName : this.objName
        };
           this.genericDispatchEvent(message);
    }
    openCompetitorcreen(){
        const  message = { 
            message: 'CompetitorScreen' ,
            recordID : this.recordId,
            index : this.index,
            screen : 3.5,
            accId : this.accId
        };
           this.genericDispatchEvent(message);
    }
    openPaymentScreen() {
        const  message = { 
            message: 'paymentScreen' ,
            recordID : this.recordId,
            screen : 3.3
        };
        this.genericDispatchEvent(message);
    }
    genericDispatchEvent(message) {
        // Creating a custom event with a payload (optional)
        const event = new CustomEvent('screen3', {
            detail: message
        });

        // Dispatching the event
        this.dispatchEvent(event);
    }
    genericDispatchToastEvent(title,message,variant){
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    // Toggle dropdowns
    
    toggleImageDropdown(){
        this.dropdown.photo  = !this.dropdown.photo ;
        const dropdownBody = this.template.querySelector('.dropdown-body-image');
        const chevronIcon = this.template.querySelector('.chevron-icon-image');
        if (dropdownBody) {
            if (this.dropdown.photo ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.targetData.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    toggleSummeryDropdown(){
        this.dropdown.summery  = !this.dropdown.summery ;
        const dropdownBody = this.template.querySelector('.dropdown-body-sum');
        const chevronIcon = this.template.querySelector('.chevron-icon-sum');
        if (dropdownBody) {
            if (this.dropdown.summery ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.targetData.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    toggleOrderDropdown(){
        this.dropdown.order  = !this.dropdown.order ;
        const dropdownBody = this.template.querySelector('.dropdown-body');
        const chevronIcon = this.template.querySelector('.chevron-icon');
        if (dropdownBody) {
            if (this.dropdown.order ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.targetData.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    toggleStockDropdown(){
        this.dropdown.stock  = !this.dropdown.stock ;
        const dropdownBody = this.template.querySelector('.dropdown-body-stk');
        const chevronIcon = this.template.querySelector('.chevron-icon-stk');
        if (dropdownBody) {
            if (this.dropdown.stock ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.visActionData.Stock.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    togglePaytmDropdown(){
        this.dropdown.payment  = !this.dropdown.payment ;
        const dropdownBody = this.template.querySelector('.dropdown-body-pyt');
        const chevronIcon = this.template.querySelector('.chevron-icon-pyt');
        if (dropdownBody) {
            if (this.dropdown.payment ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.targetData.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    toggleTaskDropdown(){
        this.dropdown.task  = !this.dropdown.task ;
        const dropdownBody = this.template.querySelector('.dropdown-body-tsk');
        const chevronIcon = this.template.querySelector('.chevron-icon-tsk');
        if (dropdownBody) {
            if (this.dropdown.task ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.targetData.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    toggleCompDropdown(){
        this.dropdown.competition = !this.dropdown.competition ;
        const dropdownBody = this.template.querySelector('.dropdown-body-cmp');
        const chevronIcon = this.template.querySelector('.chevron-icon-comp');
        if (dropdownBody) {
            if (this.dropdown.competition ) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                // if(this.targetData.length == 0){
                //     this.offSet = 0;
                //     //this.getAttendanceData('My Target',null);

                // }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    deleteSelectedFile(event){
        const id = event.currentTarget.dataset.id;
        const fileName = event.currentTarget.dataset.name;
        const msg =  "Are you sure you want to delete "+fileName +"?";
        const label =  "warning";
        const variant = "Delete Photo";
        var getConfirmation = false;
        this.handleConfirmClick(msg,label,variant,id,fileName);
        
    }

    async handleConfirmClick(msg,variant,label,id,fileName) {
        const result = await LightningConfirm.open({
            message:msg,
            variant: variant, // headerless
            label: label
        });
    
        //Confirm has been closed
    
        //result is true if OK was clicked
        if (result) {
            this.deletePhoto(id,fileName);
        } else { 
            return result ; 
        } 
    }

    async deletePhoto(recordId,fileName) {

        const msg = fileName + " deleted successfully";
        try {
            await deleteRecord(recordId);
            this.genericDispatchToastEvent('success',msg,'Success');
            this.GetOrderDetailsData();
        } catch (error) {
            //const message = 
            this.genericDispatchToastEvent('error','Connect delete photo','Error');
           
        }
    }
    previewFile(event) {
        const recordId = event.currentTarget.dataset.id;
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
    onClickVisitPopup(event){
        const msg = event.detail;
        if(msg.message == 'Close'){
            this.completeVisit = false;
            this.isDesktopCheckoutPage = true;
        }
    }
 
    createNewVisit(event){
        const msg = event.detail;
    if(msg.message == 'createNewVisit'){
        this.comment = msg.Comment;
            this.feedback = msg.feedback;
        this.handleGetLatLon('checkout');
    }
        else if(msg.message == 'Close'){
            this.completeVisit = false;
            this.isDesktopCheckoutPage = true;
        }
    }

    openBusinesSummary(event){
        const name = event.currentTarget.dataset.name;
        if(name == 'outstanding' && this.businessSummery.totalOutStanding == 0){
            this.genericDispatchToastEvent('','No outstanding amount','info');
            return;
        }
        else if(name == 'order' && this.businessSummery.totalOrderAmt == 0){
            this.genericDispatchToastEvent('','No order found','info');
            return;
        }
        else if(name == 'sales' && this.businessSummery.totalSalesAmt == 0){
            this.genericDispatchToastEvent('','No sales amount','info');
            return;
        }
        else if(name == 'visit' && this.businessSummery.AllVisit == 0){
            this.genericDispatchToastEvent('','No ovisit data','info');
            return;
        }
        const  message = { 
            message: name ,
            recordID : this.recordId,
            index : this.index,
            screen : 3.3
        };
        this.genericDispatchEvent(message);
    }
}