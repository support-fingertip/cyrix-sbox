import { LightningElement, track, api } from 'lwc';
import PLANNER_ICON from '@salesforce/resourceUrl/planner';
import SORTING_ICON from '@salesforce/resourceUrl/sorting';
import getApexData from '@salesforce/apex/visitManager.getData';
import { getLocationService } from 'lightning/mobileCapabilities';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';
import { NavigationMixin } from 'lightning/navigation';
import LightningConfirm from 'lightning/confirm';

export default class visitSummaryScreen extends NavigationMixin(LightningElement) {

    googleIcons = {
        account: GOOGLE_ICONS + "/googleIcons/apartment.png",
        sort: GOOGLE_ICONS + "/googleIcons/sort.png",
        progress: GOOGLE_ICONS + "/googleIcons/progress.png",
        play: GOOGLE_ICONS + "/googleIcons/play.png",
        forward: GOOGLE_ICONS + "/googleIcons/forward.png"
    }
    hrs = PLANNER_ICON + "/planner/screen-1-24.png";
    week = PLANNER_ICON + "/planner/screen-1-week.png";
    year = PLANNER_ICON + "/planner/screen-1-year.png";
    sortingIcon = SORTING_ICON;
    @track buttonSelectedIcon = this.hrs;
    @track buttonSelected = 'Day';
    @api isParentComp;
    @track isDropdownfilterOpen = false;
    @api isDesktop;

    @api dailyLogData;
    searchVisit = '';
    @track originalVisitData = [];
    isDayStarted = false;
    @track VisitData = [];
    isDesktopCheckoutPage = true;
    completeVisit = false;
    sortingTitle = 'Ascending'
    currentVisitId;
    selectedDropdownId = '';
    isOutletScreen = true; newVisit = false;
    selectedDropdownIndex = '';
    isOneDay = true; openVisit = false; Reshedule = false;
    isPageLoaded = false;
    StartCallHeader = 'Start Call';
    isProgressVisit;
    comment;

    //detect if LWC is running in mobile publisher
    isMobilePublisher = window.navigator.userAgent.indexOf('CommunityHybridContainer') > 0;

    @api screenHeight;


    
    @api handleUpdateChange(){
        //alert('here');
        if(this.buttonSelected == 'Day'){
            this.getTheDateBackend();
        }
    }
    connectedCallback() {
        console.log('here');
        this.isPageLoaded = true;
        this.isParentComp = this.isParentComp ? true : false;
        this.getTheDateBackend();
    }



    getTheDateBackend() {

        //this.isSpinner = true;
        getApexData({})
            .then(result => {
                this.isDayStarted = result.isDayStarted
                this.forOneDayData(result);
                const pop = this.template.querySelector(".popup");
                if (pop) {
                    pop.style.display = "";
                }
                this.isPageLoaded = false;
            })
            .catch(error => {
                this.isPageLoaded = false;
                console.error(error);
                //this.isSpinner = false;
            });
    }

    forOneDayData(result) {
        const today = new Date().toISOString().split('T')[0]; // Get today's date in 'YYYY-MM-DD' format

        let todayDay = new Date(); // Get the current date
        let day = String(todayDay.getDate()).padStart(2, '0'); // Get day and add leading zero if necessary
        let month = String(todayDay.getMonth() + 1).padStart(2, '0'); // Get month (January is 0!) and add leading zero
        let year = todayDay.getFullYear(); // Get the full year
        let inProgressStatus = false;
        // Format today's date as 'DD/MM/YYYY'
        let formattedDate = `${day}/${month}/${year}`;
        result.visit.forEach(itm => {
            const visitDate = itm.VisitDate ? new Date(itm.VisitDate).toISOString().split('T')[0] : null;
            itm.showMenu = (itm.status != 'In Progress' || itm.status != 'Planned') ? true : false;
            itm.showMenuPlanned = itm.status == 'Planned' ? true : false;
            itm.showMenuInProgress = itm.status == 'In Progress' ? true : false;
            itm.showMenuCompleted = itm.status == 'Completed' ? true : false;
            itm.showMenuMissed = itm.status == 'Missed' ? true : false;
            if (itm.status === 'In Progress') {
                inProgressStatus = true;
            }
            itm.isAcc = (itm.visitTypes == 'Dealer' || itm.visitTypes == 'Modern Trade' || itm.visitTypes == 'Distributor' || itm.visitTypes == 'Customer') ? true : false;
            itm.isMoreLoad = true;
            itm.isShowAllData = itm.formattedVisitDate == formattedDate ? false : true;
            itm.execute = visitDate === today ? true : false;
            itm.openPopup = false;
        });

        this.isProgressVisit = inProgressStatus;
        this.VisitData = result.visit;
        this.dispatchEvent(
            new CustomEvent('sendvisitdata', {
                detail: {
                    visitData: this.VisitData
                }
            })
        );
        this.originalVisitData = result.visit;
    }

    closeAllMenus() {
        this.VisitData = this.VisitData.map(item => {
            //item.showMenu = false;
            return item;
        });
    }


    handleBlur(event) {
        //const index = parseInt(event.currentTarget.dataset.index, 10);
        setTimeout(() => {
            this.closeAllMenus();
        }, 1000);
    }

    openMenu(event) {
        // const itemId = event.currentTarget.dataset.id;
        const index1 = parseInt(event.currentTarget.dataset.index, 10);
        this.VisitData = this.VisitData.map((item, i) => {
            return {
                ...item,
                openPopup: i === index1 ? !item.openPopup : false
            };
        });
    }

    handleOnclickMenu(event) {
        const itemId = event.currentTarget.dataset.id;
        const index = parseInt(event.currentTarget.dataset.index, 10);
        this.currentVisitId = itemId;
        const itemName = event.currentTarget.dataset.name;
        // Find if any visit is already in progress
        const activeVisit = this.VisitData.find(visit => visit.status === 'In Progress');

        if (activeVisit && activeVisit.id !== itemId) {

            this.genericDispatchToastEvent(
                'Warning',
                'Another visit is already in progress. Please complete it before starting a new one.',
                'warning'
            );
            return;
        }

        console.log('VISIT DATA:', JSON.stringify(this.VisitData, null, 2));
        // If same visit OR no visit is in progress → allow
        console.log('Proceeding with visit:', itemId);

        if (itemName == 'Execute_StartCall') {

            const message = {
                message: 'executeScreen',
                startCall: true,
                recordID: itemId,
                index: index,
                screen: 2.2,
                isAcc: this.VisitData[index].isAcc,
                isInProgress: this.VisitData[index].showMenuInProgress,
                isProgressVisit: this.isProgressVisit,
                isCompleted: this.VisitData[index].showMenuCompleted,
                accId: this.VisitData[index].acccountId ? this.VisitData[index].acccountId : '',
                VisitListName: this.VisitData[index].accountName,
                visitData: this.VisitData[index],
                isplayButtonClicked: true
            };
            //this.genericDispatchEvent(message); 
            //this.isOutletScreen = false;
            const visName = this.VisitData[index].accountName;
            const msg = "Are you sure you want to Start " + visName + "?";

            const label = "warning";
            const variant = "Start Day";
            const theme = "warning";
            this.handleConfirmClick(msg, label, variant, message);
        }

        else if (itemName == 'Execute') {
            const message = {
                message: 'executeScreen',
                recordID: itemId,
                startCall: false,
                index: index,
                screen: 2.2,
                isAcc: this.VisitData[index].isAcc,
                isInProgress: this.VisitData[index].showMenuInProgress,
                accId: this.VisitData[index].acccountId ? this.VisitData[index].acccountId : '',
                isProgressVisit: this.isProgressVisit,
                isCompleted: this.VisitData[index].showMenuCompleted,
                VisitListName: this.VisitData[index].accountName,
                visitData: this.VisitData[index],
                isplayButtonClicked: false
            };
            this.genericDispatchEvent(message);
            this.isOutletScreen = false;

        }
        else if (itemName == 'EndCall') {
            this.isDesktopCheckoutPage = this.isDesktop ? true : false;

            this.completeVisit = true;
            this.Reshedule = false;
            this.openVisit = true;
            //this.handleGetLatLon(itemId);
        }
        else if (itemName == 'Reshedule') {
            this.isDesktopCheckoutPage = this.isDesktop ? true : false;

            this.completeVisit = false;
            this.Reshedule = true;
            this.openVisit = true;
            //this.handleGetLatLon(itemId);
        }
        else if (itemName == 'cancel') {
            const index1 = parseInt(event.currentTarget.dataset.index, 10); // Convert index from string to number
            this.VisitData = this.VisitData.map((item, i) => {
                return {
                    ...item,
                    openPopup: i === index1 ? !item.openPopup : false
                };
            });
            this.VisitData = [...this.VisitData];
        }
        else if (itemName == 'OpenStore') {
            const index1 = parseInt(event.currentTarget.dataset.index, 10);
            const ids = this.VisitData[index1].acccountId;
            if (ids != undefined) {
                this[NavigationMixin.GenerateUrl]({
                    type: "standard__recordPage",
                    attributes: {
                        recordId: ids,
                        actionName: 'view'
                    }
                }).then(url => {
                    if (this.isDesktop) {
                        //window.location.href = url;
                        window.open(url, "_blank");
                    } else {
                        window.location.href = url;
                    }

                });
            } else {
                this.genericDispatchToastEvent('', 'Cannot open page', 'info');
            }

        }
        // console.log('Execute clicked for item: ', itemId);
        // this.closeAllMenus();
    }

    async handleConfirmClick(msg, variant, label, message) {
        const result = await LightningConfirm.open({
            message: msg,
            variant: variant, // headerless
            label: label
        });

        //Confirm has been closed

        //result is true if OK was clicked
        if (result) {
            this.genericDispatchEvent(message);
            this.isOutletScreen = false;
        } else {
            return result;
        }
    }

    handleGetLatLon(itemId) {
    console.log('this.isMobilePublisher: ' + this.isMobilePublisher);

    if (this.isMobilePublisher) {

        getLocationService().getCurrentPosition({
            enableHighAccuracy: true
        }).then((result) => {

            var newEvent = new CustomEvent(
                'locationPharmacySearch:getLatLonResponse',
                { detail: {} }
            );

            if (result && result.coords) {
                newEvent.detail.lat = result.coords.latitude;
                newEvent.detail.lon = result.coords.longitude;
                newEvent.detail.latlonsource = 'nimbus';
                newEvent.detail.status = 'success';

                console.log('newEvent: ' + JSON.stringify(newEvent));
                this.handleSaveVisitData(newEvent, itemId);
            } else {
                this.isPageLoaded = false;
            }

        }).catch((error) => {
            console.log(JSON.stringify(error));
            this.isPageLoaded = false;
        });

    }
    else if (window.navigator && window.navigator.geolocation) {

        window.navigator.geolocation.getCurrentPosition(
            (r) => {
                var newEvent = new CustomEvent(
                    'locationPharmacySearch:getLatLonResponse',
                    { detail: {} }
                );

                if (r && r.coords) {
                    newEvent.detail.lat = r.coords.latitude;
                    newEvent.detail.lon = r.coords.longitude;
                    newEvent.detail.latlonsource = 'browser';
                    newEvent.detail.status = 'success';

                    this.handleSaveVisitData(newEvent, itemId);
                } else {
                    this.isPageLoaded = false;
                }
            },
            (err) => {
                console.log(JSON.stringify(err));
                this.isPageLoaded = false;
            },
            {
                enableHighAccuracy: true,
                timeout: 10000
            }
        );

    }
    else {
        console.log('Unable to get user location.');
        this.isPageLoaded = false;
    }
}

    handleSaveVisitData(event, itemId) {
        let details = JSON.parse(JSON.stringify(event.detail));
        const now = new Date();

        let data = {
            Id: itemId,
            Comments__c: this.comment,
            Check_Out_Location__Longitude__s: details.lon,
            Check_Out_Location__Latitude__s: details.lat,
            Visit_End__c: now.toISOString(),
            Status__c: 'Completed'
        };
        const recordInput = {
            fields: data
        }
        this.saveUpdateRecord(recordInput, 'Visit Ended successfully');
    }
    saveUpdateRecord(recordInput, msg) {
        updateRecord(recordInput)
            .then((result) => {
                this.genericDispatchToastEvent('Success', msg, 'success');
                this.isProgressVisit = true;
                this.isPageLoaded = false;
                this.completeVisit = false;
                this.Reshedule = false;
                this.openVisit = false;
                this.isDesktopCheckoutPage = true;
                this.getTheDateBackend();
                // this.setDataResult(result, toastMessage);                    
            })
            .catch((error) => {
                // Handle error in record creation
                this.isDailyLog = false;
                this.isPageLoaded = false;
                console.error('Error creating record:', error);
            });
    }
    genericDispatchEvent(message) {
        // Creating a custom event with a payload (optional)
        const event = new CustomEvent('mycustomevent', {
            detail: message
        });

        // Dispatching the event
        this.dispatchEvent(event);
    }
   
    showLessMoreVisit(event) {
        const index = parseInt(event.currentTarget.dataset.index, 10);
        //this.VisitData[index].isMoreLoad = !this.VisitData[index].isMoreLoad;
        this.VisitData[index].isMoreLoad = !this.VisitData[index].isMoreLoad;
        const isMoreLoad = this.VisitData[index].isMoreLoad;
        this.VisitData[index].visits = isMoreLoad
            ? this.VisitData[index].allVisits.slice(0, 3) // If "Less", show only 3 visits
            : this.VisitData[index].allVisits;

    }
    genericDispatchToastEvent(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
    createNewVisit(event) {
        const msg = event.detail;
        if (msg.message == 'createNewVisit') {
            this.comment = msg.Comment;
            this.handleGetLatLon(this.currentVisitId);
        }
        else if (msg.message == 'Close') {
            this.completeVisit = false;
            this.Reshedule = false;
            this.openVisit = false;
            this.isDesktopCheckoutPage = true;
        }
        else if (msg.message == 'missedReason') {
            this.missedReason = msg.missedReason;
            this.missedDate = msg.missedDate;
            let data = {
                Id: this.currentVisitId,
                PostPoned_Start_Time__c: msg.missedDate,
                Missed_PostPone_Reason__c: msg.missedReason,
                Daily_Log__c: this.dailyLogData.Id,
                Status__c: 'Missed'
            };
            const recordInput = {
                fields: data
            }
            this.saveUpdateRecord(recordInput, 'Missed Visit');
        }
    }
    onChangeVisit(event) {
        const searchTerm = event.target.value.toLowerCase();
        this.searchVisit = event.target.value;
        if (!searchTerm) {
            this.VisitData = [...this.originalVisitData];
            //this.filteredVisitData = [...this.VisitData]; // Reset if search is empty
            return;
        }
        this.VisitData = this.originalVisitData.filter(product => product.accountName.toLowerCase().includes(searchTerm));
    }
    sortingVisit() {
        if (this.sortingTitle === 'Ascending') {
            this.sortingTitle = 'Descending';
            this.VisitData = [...this.VisitData].sort((a, b) =>
                a.accountName > b.accountName ? -1 : 1
            ); // Sorting in Descending Order
        } else {
            this.sortingTitle = 'Ascending';
            this.VisitData = [...this.VisitData].sort((a, b) =>
                a.accountName > b.accountName ? 1 : -1
            ); // Sorting in Ascending Order
        }
    }
}