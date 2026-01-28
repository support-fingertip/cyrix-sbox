import { LightningElement, api, track, wire } from 'lwc';
import LightningConfirm from 'lightning/confirm';
import { getLocationService } from 'lightning/mobileCapabilities';
import DAILY_LOG_OBJECT from '@salesforce/schema/Daily_Log__c';
import { createRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import DailyLogData from '@salesforce/apex/visitManager.getDailyLog';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';

import MODE_OF_TRANSPORT_FIELD from '@salesforce/schema/Daily_Log__c.Mode_of_Transport__c';
import WORK_TYPE_FIELD from '@salesforce/schema/Daily_Log__c.Travel_Type__c';
import VEHICLE_TYPE_FIELD from '@salesforce/schema/Daily_Log__c.Vehicle_Used__c';


export default class visitManager extends LightningElement {
    @track VisitDataFromOutlet = [];
    @track isEndDayPopup = false;
    @track filteredTransportModes = [];
    @track ownVehicle = false;
    @api dailylogData;
    	
   	
    @track isMenuOpen = false; // Track the menu state
    Outlet = true;
    isHomePage = false;
    header = 'Visit Plan';
    isRenderDataLoaded = true; objName;
    acccountId = '';
    visitfor = '';
    isplayButtonClicked = false;
    index;
    recordId;
    navBarClass = 'navbar';
    containerClass;
    screen = 0;
    VisitListName = '';
    productCatDropdown = [];
    proCatVal = 'All';
    searchPro = '';
    objName;
    screenHeight;
    buttonName = 'Start Day';
    createDailyLog = false;
    isDisabled = false;
    isPageLoaded = false;
    isVisitCreate = true;
    newVisitPoup = false;
    isvisitDesktop = true;
    @track placeholders = [];
    isDailyLog = true;
    outletPage = false;
    isCameraScreen = false;
    isCameraOpen=true;
    isDailyLogPopup = false;
    isDailyLogOutPopup = false;
    isProductScreen = false;
    isTaskScreen = false;
    isExecuteScreen = false;
    isPaymentScreen = false;
    isVisitHeader = false;
    isPhone = false;
    isDesktop = false;
    isCometitionScreen = false;
    currentLogId;
    visitData;
    pickListData;
    pickListData1;
    pickListData2;
    withCompanionList;
    currentLocationRequestId = '';
    isLoading = false;
     myLocationService;

 
    get modalClass() {
      
        // Fullscreen on mobile/tablet, normal modal on desktop
        return `slds-modal slds-fade-in-open  ${this.isDesktop? '' : ' slds-modal_full'}`;
    }
    //fetching picklist values
    @wire(getObjectInfo, { objectApiName: DAILY_LOG_OBJECT })
    LogRecInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$LogRecInfo.data.defaultRecordTypeId',
        fieldApiName: MODE_OF_TRANSPORT_FIELD
    })
    getPicklistValues({ error, data }) {
        if (data) {
            this.pickListData =
                data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }));
            console.log('pickListData fetching Transport picklist values:', this.pickListData);

        } else if (error) {
            console.error('Error fetching Transport picklist values:', error);
        }
    };
    @wire(getPicklistValues, {
        recordTypeId: '$LogRecInfo.data.defaultRecordTypeId',
        fieldApiName: WORK_TYPE_FIELD
    })
    getPicklistValues1({ error, data }) {
        if (data) {
            this.pickListData1 =
                data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }));
            console.log('pickListData fetching TYPE picklist values:', this.pickListData1);

        } else if (error) {
            console.error('Error fetching Type picklist values:', error);
        }
    };
    @wire(getPicklistValues, {
        recordTypeId: '$LogRecInfo.data.defaultRecordTypeId',
        fieldApiName: VEHICLE_TYPE_FIELD
    })
    getPicklistValues2({ error, data }) {
        if (data) {
            this.pickListData2 =
                data.values.map(plValue => ({
                    label: plValue.label,
                    value: plValue.value
                }));
            console.log('pickListData fetching VEHICLE TYPE picklist values:', this.pickListData2);

        } else if (error) {
            console.error('Error fetching VEHICLE Type picklist values:', error);
        }
    };
    withCompanionList = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' }
    ];



    //fetching picklist values

    handleVehicleTypeChange(event) {
        this.vehicleType = event.detail.value;

        if (this.vehicleType === 'Personal/own' || this.vehicleType === 'Office') {
            this.ownVehicle = true;
            // Only show Car and Bike
            this.filteredTransportModes = this.pickListData.filter(
                item => item.value === 'Car' || item.value === 'Bike'
            );
        } else {
            this.ownVehicle = false;
            // Show all except Car and Bike
            this.filteredTransportModes = this.pickListData.filter(
                item => item.value !== 'Car' && item.value !== 'Bike'
            );
        }

        this.transport = '';
    }

    executeScreenData = {
        isProgressVisit: false,
        isAcc: false,
        isCompleted: false,
        isInProgress: false
    };

    kmTravelled = 0;
    @track companion;
    @track transport;
    worktype;
    @track vehicleType;
    @track withCompanion = 'No';
    get isWithCompanionYes() {
        return this.withCompanion === 'Yes';
    }
    handleCompanionPicklistChange(event) {
        this.withCompanion = event.detail.value;
    }
    isShowBackButton = false;
    //detect if LWC is running in mobile publisher
    isMobilePublisher = window.navigator.userAgent.includes('CommunityHybridContainer');


    connectedCallback() {
        //this.getAttendanceData(); // Load initial data

        this.isPageLoaded = true;
        this.isDesktop = FORM_FACTOR === 'Large' ? true : false;
        this.isPhone = FORM_FACTOR === 'Small' ? true : false;
        if (FORM_FACTOR === 'Medium')
            this.isDesktop = true;
        this.disablePullToRefresh();
        this.getDailyLogDetails();
        this.containerClass = this.isDesktop ? 'slds-modal__container ' : '';
    }

    handlekmTravelled(event) {
        this.kmTravelled = event.detail.value;
    }
    handlecompanion(event) {
        this.companion = event.detail.value;
    }
    handleworktype(event) {
        this.worktype = event.detail.value;
    }
    handletransport(event) {
        this.transport = event.detail.value;
    }
    refreshData() {
        this.resetAllScreen();
        this.isPageLoaded = true;
        this.isRenderDataLoaded = true;
        this.Outlet = true;
        // this.isHomePage = true;
        this.getDailyLogDetails();
        this.isShowBackButton = false;
    }
    getDailyLogDetails() {
         DailyLogData({})
                  .then(result => {
                      this.dailylogData = result.dailyLog;
                      console.log(result);
                      if (result.dailyLog != undefined && this.dailylogData.length != 0) {
                          if (this.dailylogData.Day_ended_Time__c == null && this.dailylogData.Day_started_Time__c != null) {
                              this.isVisitCreate = true;
                              this.buttonName = 'End Day';
                              this.isDailyLog = true;
                              this.outletPage = false;
                          }
      
                          this.isDailyLog = this.dailylogData.Day_ended_Time__c != null && this.dailylogData.Day_started_Time__c != null ? false : true
                      }
                      if (result.dailyLog == undefined) {
                          this.isVisitCreate = false;
                          this.buttonName = 'Start Day';
                      }
                      this.isPageLoaded = false;
                  })
                  .catch(error => {
                      console.error(error);
                      this.isPageLoaded = false;
                  });
    }
    disablePullToRefresh() {
        const disableRefresh = new CustomEvent("updateScrollSettings", {
            detail: {
                isPullToRefreshEnabled: false
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(disableRefresh);
    }
    openMenu() {
        this.isMenuOpen = !this.isMenuOpen; // Toggle menu state
        const menu = this.template.querySelector('.nav-menu');
        if (this.isMenuOpen) {
            menu.style.left = '0'; // Show the menu (slide in)
        } else {
            menu.style.left = '-120%'; // Hide the menu (slide out)
        }
    }


    handleCustomEvent(event) {
        this.isShowBackButton = true;
        const msg = event.detail;

        if (msg.message == 'executeScreen') {
        
            this.VisitListName = msg.VisitListName;
            this.header = this.VisitListName;
            this.Outlet = false;
            this.recordId = msg.recordID;
            this.index = msg.index;
            this.isExecuteScreen = true;
            this.screen = msg.screen;
            this.executeScreenData.isProgressVisit = msg.isProgressVisit;
            this.executeScreenData.isAcc = msg.isAcc;
            this.executeScreenData.isCompleted = msg.isCompleted;
            this.executeScreenData.isInProgress = msg.isInProgress;
            this.showVisitButton = msg.isInProgress
            this.outletPage = true;
            this.acccountId = msg.accId;
            this.visitfor = msg.visitfor;
            this.objName = msg.objName;
            this.visitData = msg.visitData;
            this.isplayButtonClicked = msg.isplayButtonClicked;
            //this.isVisitHeader = false;
            this.isVisitHeader = true;
            if (msg.startCall) {
                
                this.executeScreenData.isInProgress = true;
            }
        }

    }
    resetAllScreen() {
        this.isBusinessSummaryScreen = false;
        this.isExecuteScreen = false;
        this.isVisitHeader = false;
        this.isProductScreen = false;
        this.isPaymentScreen = false;
        this.Outlet = false;
        this.isTaskScreen = false;
        this.isHomePage = false;
        this.isVisitHeader = false;
        this.isHomePage = false;
        this.isVisitCreate = false;
        this.outletPage = false;
        this.isCameraScreen = false;
    }
    handleProductScreen(event) {
        this.isShowBackButton = true;
        const msg = event.detail;
        this.resetAllScreen();
        this.outletPage = true;
        this.navBarClass = 'navbar';
        if (msg.message == 'productScreen') {
            this.header = 'Product';
            this.recordId = msg.recordID;
            this.index = msg.index;
            this.screen = msg.screen;
            this.isVisitHeader = true;
            this.isProductScreen = true;
            //this.productCatDropdown = msg.productCatDropdown;
            this.currentLogId = this.dailylogData.Id == undefined ? this.dailylogData.id : this.dailylogData.Id;
        }
        else if (msg.message == 'StockSCreen') {
            this.header = 'Stock';
            this.recordId = msg.recordID;
            this.index = msg.index;
            this.screen = msg.screen;
            this.isVisitHeader = true;
            this.isProductScreen = true;
            // this.productCatDropdown = msg.productCatDropdown;
            this.currentLogId = this.dailylogData.Id == undefined ? this.dailylogData.id : this.dailylogData.Id;
        }
        else if (msg.message == 'paymentScreen') {
            this.header = 'Payment follow up';
            this.recordId = msg.recordID;
            this.screen = msg.screen;
            this.isVisitHeader = true;
            this.isPaymentScreen = true;
        }
        else if (msg.message == 'taskScreen') {
            this.header = 'Task';
            this.recordId = msg.recordID;
            this.screen = msg.screen;
            this.isTaskScreen = true;
            this.outletPage = true;
        }
        else if (msg.message == 'CompetitorScreen') {
            this.header = 'Competitor Screen';
            this.recordId = msg.recordID;
            this.screen = msg.screen;
            this.isCometitionScreen = true;
            this.outletPage = true;
        }
        else if (msg.message == 'checkout') {
            this.isExecuteScreen = true;
            this.executeScreenData.isInProgress = false;
        }
        else if (msg.message == 'cameraScreen') {
            this.header = 'Capture Image';
            this.recordId = msg.recordID;
            this.screen = msg.screen;
            this.isCameraScreen = true;
            this.outletPage = true;
        }

        else if (msg.message == 'order' || msg.message == 'outstanding' || msg.message == 'sales' || msg.message == 'visit') {
            this.recordId = msg.recordID;
            this.screen = msg.screen;
            this.isBusinessSummaryScreen = true;
            this.objName = msg.message;
        }
    }

    handleOrderScreen(event) {
        this.isShowBackButton = true;
        const msg = event.detail;
        if (msg.message == 'executeScreen') {
            this.resetAllScreen();
            if (msg.screen == 3.2) {
                this.header = this.VisitListName;
                this.isExecuteScreen = true;
                this.screen = 3;
                this.isVisitHeader = true;
                this.outletPage = true;
                this.isVisitCreate = true;
                this.outletPage = true;

            }
        }
        else if (msg.message == 'comboBox') {
            this.navBarClass = 'navBarSpace';
            this.productCatDropdown = msg.productCatDropdown;
        }
    }
    goBackScreen() {
        const sc = this.screen;
        if (sc == 1) {
            this.isShowBackButton = false;
            return;
        }
        this.resetAllScreen();
        var changeShadow = false;
        if (sc == 0) {
            this.Outlet = true;
            this.header = 'Visit Plan';
            this.isVisitCreate = true;
            this.isShowBackButton = false;
        }
        if (sc == 1) {
            // changeShadow = true;
            // this.header = 'Visit type';
            // this.isVisitCreate = true;
            // this.isHomePage = true;
            // this.Outlet = false;
            // this.header = 'Home';
            // this.isExecuteScreen = false;
        }
        else if (sc == 2) {
            changeShadow = true;
            this.header = 'Visit Plan';
            // this.isHomePage = true;
            // this.header = 'Home';
            this.Outlet = true;
            this.screen = 1;
            this.isVisitCreate = true;
            this.isShowBackButton = false;
            // this.isVisitHeader = false;
        }
        else if (sc == 2.2) {
            this.Outlet = true;
            this.header = 'Visit Plan';
            this.screen = 2;
            this.isVisitCreate = true;
            this.isShowBackButton = false;
        }
        else if (sc == 3) {
            changeShadow = true;
            this.Outlet = true;
            this.header = 'Outlet';
            this.screen = 2;
            this.isVisitHeader = true;
            this.isVisitCreate = true;
            this.isShowBackButton = false;
        }
        else if (sc == 3.2) {
            this.header = this.VisitListName;// 'Visit Call';
            this.isExecuteScreen = true;
            this.screen = 3;
            this.isVisitHeader = true;
            this.outletPage = true;
            this.isVisitCreate = true;
            this.outletPage = true;
        }
        else if (sc == 3.3) {
            this.header = this.VisitListName;//'Visit Call';
            this.isExecuteScreen = true;
            this.screen = 3;
            this.isVisitHeader = true;
            this.outletPage = true;
        }
        else if (sc == 3.4) {
            this.header = this.VisitListName;// 'Visit Call';
            this.isExecuteScreen = true;
            this.screen = 3;
            this.isVisitHeader = true;
            this.outletPage = true;
        }
        else if (sc == 3.5) {
            this.header = this.VisitListName;//'Visit Call';
            this.isExecuteScreen = true;
            this.screen = 3;
            this.isVisitHeader = true;
            this.outletPage = true;
            this.isCometitionScreen = false;
        }
        if (changeShadow) {
            const allMenuItems = this.template.querySelectorAll('.menu-items');
            allMenuItems.forEach(item => {
                if (item.dataset.id === this.header) {
                    item.classList.add('selected');
                } else {
                    item.classList.remove('selected');
                }
            });
        }
    }

    /*Getting geoLocation*/
handleGetLatLon(locationProgress) {
    this.isLoading = true;
    this.isDisabled = true; // ✅ add (prevents double-click stress)
    let isResolved = false;
    this.currentLocationRequestId = null;

    const requestId = Math.random().toString(36).substring(2);
    this.currentLocationRequestId = requestId;

    // Timeout fallback
    const timeoutTimer = setTimeout(() => {
        // ✅ also guard against stale requests
        if (this.currentLocationRequestId !== requestId || isResolved) return;

        this.isLoading = false;
        this.isDisabled = false;
        this.currentLocationRequestId = null;

        if (locationProgress === 'Checkin') {
            this.buttonName = 'Start Day';
        }
        this.genericDispatchEvent('Error', 'Unable to fetch location in time. Please try again.', 'error');
    }, 15000);

    // ✅ FAST options first (much quicker), then fallback to accurate
    const fastMobileOptions = { enableHighAccuracy: false };
    const accurateMobileOptions = { enableHighAccuracy: true };

    const fastBrowserOptions = { enableHighAccuracy: false, timeout: 8000, maximumAge: 60000 };
    const accurateBrowserOptions = { enableHighAccuracy: true, timeout: 12000, maximumAge: 0 };

    // ------------------ MOBILE ------------------
    if (this.isMobilePublisher) {
        this.myLocationService = getLocationService();

        if (this.myLocationService == null || !this.myLocationService.isAvailable()) {
            // ✅ stop properly (no hanging spinner)
            if (this.currentLocationRequestId !== requestId || isResolved) return;
            isResolved = true;
            clearTimeout(timeoutTimer);

            this.isLoading = false;
            this.isDisabled = false;
            this.currentLocationRequestId = null;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'LocationService Is Not Available',
                    message: 'Please enable location permission',
                    variant: 'error'
                })
            );
            return;
        }

        // ✅ FAST first
        this.myLocationService.getCurrentPosition(fastMobileOptions)
            .then((result) => {
                if (this.currentLocationRequestId !== requestId || isResolved) return;
                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null;

                const newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse', { detail: {} });
                newEvent.detail.lat = result.coords.latitude;
                newEvent.detail.lon = result.coords.longitude;
                newEvent.detail.latlonsource = 'nimbus';
                newEvent.detail.status = 'success';

                this.handleSaveDailyLog(newEvent, locationProgress);
            })
            .catch(() => {
                // ✅ fallback to accurate
                return this.myLocationService.getCurrentPosition(accurateMobileOptions);
            })
            .then((result) => {
                if (!result) return;
                if (this.currentLocationRequestId !== requestId || isResolved) return;

                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null;

                const newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse', { detail: {} });
                newEvent.detail.lat = result.coords.latitude;
                newEvent.detail.lon = result.coords.longitude;
                newEvent.detail.latlonsource = 'nimbus';
                newEvent.detail.status = 'success';

                this.handleSaveDailyLog(newEvent, locationProgress);
            })
            .catch((error) => {
                if (this.currentLocationRequestId !== requestId || isResolved) return;
                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null;

                console.error('Mobile location error:', error);
                this.isLoading = false;
                this.isDisabled = false; // ✅ fix missing reset
                this.isPageLoaded = false;

                if (locationProgress === 'Checkin') {
                    this.buttonName = 'Start Day';
                }
                this.genericDispatchEvent('Error', 'Unable to fetch location. Please ensure location is enabled.', 'error');
            });

        return;
    }

    // ------------------ BROWSER ------------------
    if (window.navigator && window.navigator.geolocation) {
        const getPos = (opts) =>
            new Promise((resolve, reject) =>
                window.navigator.geolocation.getCurrentPosition(resolve, reject, opts)
            );

        // ✅ FAST first
        getPos(fastBrowserOptions)
            .catch(() => getPos(accurateBrowserOptions))
            .then((r) => {
                if (this.currentLocationRequestId !== requestId || isResolved) return;
                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null;

                const newEvent = new CustomEvent('locationPharmacySearch:getLatLonResponse', { detail: {} });
                newEvent.detail.lat = r.coords.latitude;
                newEvent.detail.lon = r.coords.longitude;
                newEvent.detail.latlonsource = 'browser';
                newEvent.detail.status = 'success';

                this.handleSaveDailyLog(newEvent, locationProgress);
            })
            .catch((err) => {
                if (this.currentLocationRequestId !== requestId || isResolved) return;
                isResolved = true;
                clearTimeout(timeoutTimer);
                this.currentLocationRequestId = null;

                console.error('Browser location error:', err?.code, err?.message);
                this.isLoading = false;
                this.isDisabled = false;
                this.isPageLoaded = false;

                if (locationProgress === 'Checkin') {
                    this.buttonName = 'Start Day';
                }

                // ✅ better message based on real error
                const msg =
                    err?.code === 1 ? 'Location permission denied. Please allow location permission.' :
                    'Unable to fetch location. Please ensure location is enabled.';
                this.genericDispatchEvent('Error', msg, 'error');
            });

        return;
    }

    // ------------------ NOT SUPPORTED ------------------
    console.log('Unable to get user location.');
    this.isPageLoaded = false;

    isResolved = true;
    clearTimeout(timeoutTimer);
    this.currentLocationRequestId = null;

    this.isDisabled = false;
    this.isLoading = false;

    if (locationProgress === 'Checkin') {
        this.buttonName = 'Start Day';
    }
    this.genericDispatchEvent('Error', 'Location not supported on this device.', 'error');
}



    /*Daily Log save Data*/
    handleSaveDailyLog(event, locationProgress) {

        let details = JSON.parse(JSON.stringify(event.detail));
        if (locationProgress == 'Checkin') {
            let data = {
                // Name : new Date(),
                Clock_In_Location__Longitude__s: details.lon,
                Clock_In_Location__Latitude__s: details.lat,
                Day_started_Time__c: new Date(),
                Companion__c: this.companion,
                Odometer_Starting_Kms__c: this.kmTravelled,
                Mode_of_Transport__c: this.transport,
                Travel_Type__c: this.worktype,
                Vehicle_Used__c: this.vehicleType,
                With_Companion__c: this.withCompanion
            };
            const fields = data;
            const recordInput = { apiName: DAILY_LOG_OBJECT.objectApiName, fields };
            this.saveUpdateRecord(createRecord, recordInput, 'Day Started Successfully');
        }

        else if (locationProgress == 'Checkout') {
            let date = new Date();
            let formattedDate = date.toISOString();
            let data = {
                Id: this.dailylogData.Id == undefined ? this.dailylogData.id : this.dailylogData.Id,
                Clock_Out_Location__Latitude__s: details.lat,
                Clock_Out_Location__Longitude__s: details.lon,
                Day_ended_Time__c: formattedDate,
                Odometer_Ending_Kms__c: this.kmTravelled
            };
            const recordInput = {
                fields: data
            }
            this.saveUpdateRecord(updateRecord, recordInput, 'Day Ended Successfully');
        }
    }

    saveUpdateRecord(actionToPerform, recordInput, toastMessage) {
        actionToPerform(recordInput)
            .then((result) => {

                this.isDailyLogOutPopup = false;
                this.isDailyLogPopup = false;
                this.createDailyLog = false;
                this.isvisitDesktop = true;
                this.dailylogData = result;
                this.genericDispatchEvent('Success', toastMessage, 'success');
                this.isPageLoaded = false;

                // ❌ original logic (keep it, don't touch)
                this.isVisitCreate = toastMessage == 'Day Started' ? true : false;
                if (toastMessage == 'Day Ended') {
                    this.isDailyLog = false;
                }

                /* ✅ NEW: normalize based on the ACTUAL toast messages you pass
                   ('Day Started Successfully' / 'Day Ended Successfully')
                */
                if (toastMessage === 'Day Started Successfully') {
                    this.isVisitCreate = true;          // allow visit creation
                    this.buttonName = 'End Day';        // show End Day button
                    this.isDailyLog = true;
                    this.kmTravelled = 0;           // daily log in progress
                } else if (toastMessage === 'Day Ended Successfully') {
                    this.isVisitCreate = false;         // no new visit until restart
                    this.isDailyLog = false;            // log closed
                    this.buttonName = 'Start Day';      // show Start Day button
                }

                // ✅ NEW: hard refresh Daily Log state from server
                this.getDailyLogDetails();
            })
            .catch((error) => {
                // Handle error in record creation
                this.isDailyLog = false;
                this.isPageLoaded = false;
                console.error('Error creating record:', error);
            });
    }

    isStartEndDay() {

        this.isRenderDataLoaded = true;
        const headerName = this.buttonName;
        if (headerName == 'Start Day') {
            this.isDailyLogPopup = true;
            this.createDailyLog = true;
            this.isDisabled = false;
            this.isvisitDesktop = this.isDesktop ? true : false;
            // this.isPageLoaded = true;
            // this.handleGetLatLon('Checkin');
            // this.buttonName = 'End Day';
            // this.isVisitCreate = false;

        }
        /*  else if(headerName == 'End Day'){
                  const msg = 'Are you sure you want to end the day’s visit?';
                  const label= 'End call';
                  const theme = 'error';
                  this.genericConfirmationPopup(msg,label,theme);
  
          }*/
        else if (headerName == 'End Day') {
            this.isDisabled = false;
            if (this.ownVehicle == true || this.dailylogData.Vehicle_Used__c == 'Office' || this.dailylogData.Vehicle_Used__c == 'Personal/own') {
                this.isDailyLogOutPopup = true;
                this.isDailyLogPopup = true;
                this.isvisitDesktop = this.isDesktop ? true : false;
            }
            else {
                const msg = 'Are you sure you want to end the day’s visit?';
                const label = 'End call';
                const theme = 'error';
                this.genericConfirmationPopup(msg, label, theme);
            }


        }

    }
    closeDailypopup() {
        if (this.isDailyLogOutPopup == true) {
            this.isDailyLogOutPopup = false;
        }
        else {
            this.createDailyLog = false;
            this.kmTravelled = 0;
        }
        this.isDailyLogPopup = false;
        this.isvisitDesktop = true;

    }

    saveDailyLogLocation() {
        try {
            const kmDis = this.kmTravelled != '' ? parseFloat(this.kmTravelled) : 0;

            /* -- ODOMETER VALIDATION (only End Day + Office/Personal vehicle) ------------------------------ */

            if (this.buttonName === 'End Day' &&
                this.dailylogData &&
                (this.dailylogData.Vehicle_Used__c === 'Office' ||
                    this.dailylogData.Vehicle_Used__c === 'Personal/own')) {

                const startOdo = this.dailylogData.Odometer_Starting_Kms__c
                    ? parseFloat(this.dailylogData.Odometer_Starting_Kms__c)
                    : null;
                if (startOdo != null && !isNaN(startOdo) && kmDis <= startOdo) {
                    const msg = "End Odometer reading must be greater than Start Odometer reading.";
                    const title = '';
                    const variant = 'warning';
                    this.genericDispatchEvent(title, msg, variant);
                    return;
                }
            }


            if (kmDis <= 0) {
                if ((this.buttonName == 'Start Day' && this.ownVehicle == true) ||
                    (this.buttonName == 'End Day' &&
                        (this.dailylogData.Vehicle_Used__c == 'Office' ||
                            this.dailylogData.Vehicle_Used__c == 'Personal/own'))) {
                    const msg = "Enter ODO Reading";
                    const title = '';
                    const variant = 'warning';
                    this.genericDispatchEvent(title, msg, variant);
                    return;
                }
            }

               if (this.buttonName === 'End Day'){
if(this.VisitDataFromOutlet){
                const activeVisit = this.VisitDataFromOutlet.find(visit => visit.status === 'In Progress');
                if (activeVisit) {
                    const msg = "You have an active visit. Please complete it before end the day.";
                const title = '';
                const variant = 'warning';
                this.genericDispatchEvent(title, msg, variant);
                return;
                }
            }
        }

            if ((this.worktype == '' || this.worktype == undefined) && this.buttonName == 'Start Day') {
                const msg = "Add Work type..";
                const title = '';
                const variant = 'warning';
                this.genericDispatchEvent(title, msg, variant);
                return;
            }
            else if ((this.vehicleType == '' || this.vehicleType == undefined) && this.buttonName == 'Start Day') {
                const msg = "Add Vehicle Type .";
                const title = '';
                const variant = 'warning';
                this.genericDispatchEvent(title, msg, variant);
                return;
            }
            else if ((this.transport == '' || this.transport == undefined) && this.buttonName == 'Start Day') {
                const msg = "Add Mode Of Transport.";
                const title = '';
                const variant = 'warning';
                this.genericDispatchEvent(title, msg, variant);
                return;
            }
            else if ((this.companion == '' || this.companion == undefined) && this.buttonName == 'Start Day' && this.withCompanion == 'Yes') {
                const msg = "Add Companion Name.";
                const title = '';
                const variant = 'warning';
                this.genericDispatchEvent(title, msg, variant);
                return;
            }

            this.isDisabled = true;
            this.isPageLoaded = true;

            if (this.buttonName == 'Start Day') {
                this.buttonName = 'End Day';
                this.handleGetLatLon('Checkin');
            }
            else if (this.buttonName == 'End Day') {
                this.handleGetLatLon('Checkout');
            }
        } catch (error) {
            console.error(error.m);
        }
    }



    //changed the popups
    async genericConfirmationPopup(message, label, theme) {
        const result = await LightningConfirm.open({
            message: message,
            variant: 'header',
            label: label,
            theme: theme
            // setting theme would have no effect
        });
        if (result) {
            this.isDailyLog = false;
            this.isPageLoaded = true;
            this.handleGetLatLon('Checkout');
            this.isVisitCreate = false;
            //true
        } else {
            //false
        }
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
    visitCreate() {
        this.isvisitDesktop = this.isDesktop ? true : false;
        this.currentLogId = this.dailylogData.Id == undefined ? this.dailylogData.id : this.dailylogData.Id;
        this.newVisitPoup = true;
    }
    onClickVisitPopup(event) {
 
        const msg = event.detail;

        if (msg.message == 'Close') {
            this.newVisitPoup = false;
            this.isvisitDesktop = true;
        }
      if (msg.message == 'Save') {
            this.genericDispatchEvent('Success', 'Visit Created successfully', 'success');
            this.newVisitPoup = false;
            this.isvisitDesktop = true;
            if (this.Outlet) {
                setTimeout(() => {
                    const childComp = this.template.querySelector('c-visit-summary-screen');
                    if (childComp) {
                        childComp.handleUpdateChange();
                    } else {
                        console.error('Child component not found');
                        //alert(('Child component not found'))
                    }
                }, 0);

               
            }
        }
    
    }
    completeVisit() {
        setTimeout(() => {
            const childComp = this.template.querySelector('c-visit-Order-execute-screen');
            if (childComp) {
                childComp.handleCheckOutVisit();
            } else {
                console.error('Child component not found');
                //alert(('Child component not found'))
            }
        }, 0);
    }
    handleChangeCategory(event) {
        const val = event.detail.value;
        setTimeout(() => {
            const childComp = this.template.querySelector('c-product-screen');
            if (childComp) {
                //childComp.category = val;
                childComp.handleChangeCategory(val);
            } else {
                console.error('Child component not found');
                //alert(('Child component not found'))
            }
        }, 0);
    }
    onChangeProducts(event) {
        const val = event.target.value;
        setTimeout(() => {
            const childComp = this.template.querySelector('c-product-screen');
            if (childComp) {
                //childComp.category = val;
                childComp.onChangeProducts(val);
            } else {
                console.error('Child component not found');
                //alert(('Child component not found'))
            }
        }, 0);
    }

    getVisitDataFromOutletScreen(event) {
        // const canSwitch = event.detail.canSwitch;
        const visitData = event.detail.visitData;

        this.VisitDataFromOutlet = [...visitData];
        console.log('visitData:', visitData);


    }
}