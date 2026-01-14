import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import FORM_FACTOR from '@salesforce/client/formFactor';
import userId from '@salesforce/user/Id';
import getExpenses from '@salesforce/apex/ExpenseController.getExpenses';
import validateFiles from '@salesforce/apex/ExpenseController.validateFiles';
import save from '@salesforce/apex/ExpenseController.saveExpense';
export default class CreateNewExpense extends LightningElement {
    @api recordId;
    isDesktop = false;
    isPhone = false;
    userId = userId;
    OwnerId = userId;
    expenseStartDate;
    expenseEndDate;
    @track grandTotal = 0;
    @track errorMessage = '';
    maxDaysAllowed = 10;
    showDropdown = false;

    isLoading = false;
    expenseTitle = 'New Expense';
    currentStep = '1';

    showExpense = true;
    showUpdate = false;
    isButtonDisabled = false;
    showUpload = false;
    showExpeneItems = false;


    @track expense = {};
    @track lineItems = [];
    @track days = [];
    @track AllDays = [];
    @track cities = [];
    @track cityOptions = [];
    @track eligibilities = {};
    @track travelTypes = [];
    @track approvalStatus = [];
    @track travelModes = [];
    @track expenseTypes = [];
    @track travelTypeOptions = [];
    @track foodTypeOptions = [];
    @track DeleteExpLine = [];

    isDisabled = false;
    backDatedEntry = 1;
    perKMChargeBike = 0;
    perKMChargeCar = 0;
    dailylimitAuto = '';
    dailylimitCar = '';
    dailylimitBike = '';
    daAmountUP = 0;
    daAmountHQ = 0;
    daAmountDIS = 0;
    localConveyanceAmont = 0;
    lodgingfoodAmountLimit = 0;
    lodgingLimit = '';
    totalBikekM = 0;
    totalCarkM = 0;
    totalAutoAmt = 0;
    lodging = 0;
    customClass = 'slds-size_1-of-3 slds-p-horizontal_small';
    loggedInUser = {};
    showLimitFields = false;
    approverId = '';
    OpenedByOwner = false;
    OpenedByApprover = false;
    submitforApproval = false;
    approveRecord = false;
    rejectRecord = false;
    showSubmitforApproval = true;
    expenseBackDayEntry = 0;
    dailyKmLimitHq = 0;
    dailyKmLimitUp = 0;
    mobileExpenseLimit = 0;
    dailyKmLimitHqDistrictHead = 0;
    isDistrictInCharge = false;
    customheaderClass = 'slds-size_1-of-3 slds-p-horizontal_small';
    isAllDaysSelected = false;
    totalNoOfDays = 0;
    showDoneButton = false;
    disableButtons = true;

    //Approval Popup
    isShowApprovalPopUp = false;
    approvalHeader = 'Submit Expenses';
    containerClass = 'slds-modal__container';
    isApprovalDisabled = false;
    selectedDays = 0;
    selectedAmount = 0;
    periodName = 0;
    approvalButtonLabel = 'Submit';
    showBody = true;
    approvalComments = '';
    @track commentHistoryList = [];
    @track activeSection = [];
    showComments = false;
    @track isExpanded = false;
    approvalStatusVal = 'All';
    isShowAddDeleteButtons = true;
    isCarEnabled = false;
    isBikeEnabled = false;
    isAutoEnabled = false;


    connectedCallback() {
        this.isDesktop = FORM_FACTOR === 'Large' ? true : false;
        this.isPhone = FORM_FACTOR === 'Small' ? true : false;
        this.expenseTitle = this.recordId ? 'Edit Expense' : 'New Expense';
        this.containerClass = this.isDesktop ? 'slds-modal__container ' : '';
        this.customClass = this.isDesktop ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-1 slds-p-horizontal_small';
        this.customheaderClass = this.isDesktop ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
        this.expense = {
            sObjectType: 'Expense__c',
            Start_Date__c: '',
            End_Date__c: '',
            OwnerId: '',
            Approval_Status__c: 'Not Submitted',
            Comments__c: '',
            Id: null
        };
        this.disablePullToRefresh();
        this.getExpenseData();
    }




    handleDailyKmLimit(event) {
        const enteredkm = event.target.value;
        const localId = event.target.dataset.localid;
        var taAmount = 0;
        // Find the day containing the line item using the localId
        const dayData = this.days.find(day => day.lineItems.some(item => item.localId__c === localId));
        const lineItem = dayData.lineItems.find(item => item.localId__c === localId);
        if (lineItem.Travel_Mode__c == 'Bike') {
            taAmount = enteredkm * this.perKMChargeBike;
        } else if (lineItem.Travel_Mode__c == 'Car') {
            taAmount = enteredkm * this.perKMChargeCar;
        }
        lineItem.Amount__c = taAmount;
        lineItem.Total_KM__c = enteredkm;
        this.getGrandTotal();

    }
    getExpenseData() {
        try {
            this.isLoading = true;
            getExpenses({
                recordId: this.recordId,
            })
                .then(data => {
                    this.expenseStartDate = data.startDate;
                    this.expenseEndDate = data.endDate;
                    this.travelTypes = data.travelTypes;
                    this.eligibilities = data.eligibilities;
                    this.lineItems = data.lineItems;
                    this.days = data.days;
                    this.totalNoOfDays = this.days.length || 0;
                    this.perKMChargeBike = this.eligibilities.Conveyance_Allowance_per_KM_Bike__c || 0;
                    this.perKMChargeCar = this.eligibilities.Conveyance_Allowance_per_KM_Own_Car__c || 0;
                    this.daAmountHQ = this.eligibilities.Daily_Allowance_HQ__c || 0;
                    this.daAmountUP = this.eligibilities.DA_Other_State__c || 0;
                    this.daAmountDIS = this.eligibilities.DA_Other_District__c || 0
                    this.isDistrictInCharge = data.isDistrictInCharge || false;
                    this.localConveyanceAmont = this.eligibilities.Local_Conveyance__c;
                    this.lodging = this.eligibilities.Lodging__c || 0;
                    this.dailylimitAuto = this.eligibilities.Monthly_limit_Auto__c || '';
                    this.dailylimitCar = this.eligibilities.Monthly_Limit_Car__c || '';
                    this.dailylimitBike = this.eligibilities.Monthly_limit_Auto__c || '';
                    this.lodgingfoodAmountLimit = this.eligibilities.Lodging_Food_Expenses__c || 0;
                    this.lodgingLimit = this.eligibilities.Lodging__c || 0;
                    this.travelTypeOptions = this.getPicklistValueFromList(data.travelTypes || []);
                    this.expenseTypes = this.getPicklistValueFromList(data.expenseTypes || []);
                    this.travelModes = this.getPicklistValueFromList(data.travelModes || []);
                    this.foodTypeOptions = this.getPicklistValueFromList(data.foodTypes || []);
                    this.approvalStatus = this.getFilteredPicklistValueList(data.approvalStatus || []);
                    this.loggedInUser = data.LoggedInUser;
                    this.totalBikeKM = 0;
                    this.totalCarKM = 0;
                    this.totalAutoAmt = 0;
                    this.isCarEnabled = data.isCarEnabled;
                    this.isBikeEnabled = data.isBikeEnabled;
                    this.isAutoEnabled = data.isAutoEnabled;
                    if (!data.expense) {
                        let expense = {
                            sObjectType: 'Expense__c',
                            Start_Date__c: data.startDate,
                            End_Date__c: data.endDate,
                            Approval_Status__c: 'Not Submitted',
                            Executive_Name__c: this.loggedInUser.Name,
                            Expense_Approver_L1__c: null,
                            Expense_Approver_L2__c: null,
                            Expense_Finance_Department_Approver__c: null,
                            Comments__c: '',
                            Id: null
                        };
                        this.expense = { ...expense };
                        this.commentHistoryList = [];
                        this.showComments = false;
                        this.isShowAddDeleteButtons = true;
                    }
                    else {
                        this.totalAutoAmt = data.expense.Total_Amount_Auto__c;
                        this.totalBikeKM = data.expense.Total_KM_Bike__c;
                        this.totalCarKM = data.expense.Total_KM_Car__c;
                        this.expense = data.expense;
                        this.OwnerId = this.expense.OwnerId;
                        this.showLimitFields = this.loggedInUser.Id !== this.expense.OwnerId;
                        let updatedComments = data.expense.Comments__c || '';
                        this.commentHistoryList = this.parseCommentHistory(updatedComments);
                        this.showComments = this.commentHistoryList.length > 0 ? true : false;
                        this.isShowAddDeleteButtons = (this.loggedInUser.Id == this.expense.OwnerId) || (this.loggedInUser.isAdmin__c)
                    }


                    this.populateDays(); //-- lineitem--

                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                    this.errorMessage = error;
                });
        } catch (error) {
            console.error('getExpenseData' + error.message);
        }
    }

    populateDays() {
        if (!Array.isArray(this.days)) {
            this.days = [];
            return;
        }

        // Define the custom order mapping
        const expenseTypeOrder = {
            'TA': 1,
            'DA': 2,
            'Food': 3,
            'Accommodation': 4,
            'Lodging + Food': 5,
            'Local Conveyance': 6,
            'Courier Charges': 7,
            'Mobile Charges': 8,
            'Transport Conveyance': 9,
            'Other/MISC': 10
        };

        const enrichedDays = this.days.map(dayData => {
            const dateStr = dayData.Date__c;

            let dateStrIndia = '';
            if (dateStr) {
                const parts = dateStr.split('-');
                dateStrIndia = `${parts[2]}-${parts[1]}-${parts[0]}`;
            }

            // Collect related line items
            let lineItemsForDay = [];
            if (Array.isArray(this.lineItems)) {

                console.log('line' + JSON.stringify(this.lineItems));
                lineItemsForDay = this.lineItems
                    .filter(item => item.Daily_Log__c === dayData.Id)
                    .map(item => ({
                        ...item,
                        Id: item.Id,
                        Travel_Type__c: dayData.Travel_Type__c,
                        sObjectType: 'Expense_Line_Item__c',
                        Approval_Status__c: item.Approval_Status__c,
                        localId__c: item.localId__c,
                        fileUId: '',
                        fileRecordId: item.Id,
                        expenseTypeId: 'Expense_Type' + item.localId__c,
                        travelModeId: item.Travel_Mode__c + '' + item.localId__c,
                        Expense_Date__c: item.Expense_Date__c,
                        Travel_Type__c: item.Travel_Type__c,
                        Expense_Type__c: item.Expense_Type__c,
                        Travel_Mode__c: item.Travel_Mode__c,
                        Working_Hours__c: item.Working_Hours__c || 0,
                        Total_KM__c: item.Total_KM__c || 0,
                        Amount__c: item.Amount__c || 0,
                        System_Calculated_Amount__c: item.System_Calculated_Amount__c || 0,
                        Remarks__c: item.Remarks__c,
                        Expense__c: item.Expense__c,
                        Daily_Log__c: item.Daily_Log__c,
                        Calculated_KM__c: item.Calculated_KM__c,
                        lodging_Limit__c: item.lodging_Limit__c,
                        TA_Limit__c: item.TA_Limit__c,
                        DA_Limit__c: item.DA_Limit__c,
                        Local_Conveyance_Limit__c: item.Local_Conveyance_Limit__c,
                        expenseTypes: this.getExpenseTypePicklistValues(item),
                        travelModes: this.getTravelModePicklistValues(item),
                        isTA: this.checkIsTA(item),
                        isTransportCarBike: this.checkIsTransportCarBike(item),
                        isTransportNotBikeCar: this.checkIsTransportNotBikeCar(item),
                        isDA: this.checkIsDA(item),
                        isLodging: this.checkIsLodging(item),
                        isLocalConveyance: this.checkIsLocalConveyance(item),
                        isOtherExpense: this.checkIsOtherExpense(item),
                        showDropdown: false,
                        remarksMandatory: this.checkIsRemarksMandatory(item),
                        fileUploadMandatory: this.checkIsfileMandatory(item),
                        showFoodExpense: this.checkisShowFood(item),
                        isDisabled: !this.isShowDeleteButton(item),
                        isShowDeleteButton: this.isShowDeleteButton(item),
                        customClass: this.getApprovalStatusClass(item),
                        Lodging_Food_Expense_Limit__c: item.Lodging_Food_Expense_Limit__c,
                        isLodgingFoodExpense: this.checkisLodgingFoodExpense(item),
                        isMobileExpense: this.checkIsMobileExpense(item),
                        customClassLine: this.getItemClass(item),
                        disableExpenseType: this.disableExpenseType(item),
                        disableDaAmout: this.disableDaAmount(item),
                        isSelected: false,
                        isCheckboxDisabled: this.getCheckBoxDisabled(item),
                        Is_Updated__c: false,
                        isShowModeTransport: this.checkIstransportExpense(item),
                    }))

                    // Sort based on Expense_Type__c priority
                    .sort((a, b) => {
                        const orderA = expenseTypeOrder[a.Expense_Type__c] || 99;
                        const orderB = expenseTypeOrder[b.Expense_Type__c] || 99;
                        return orderA - orderB;
                    });
            }
            return {
                Date__c: dateStr,
                DateFormatted: dateStrIndia,
                Travel_Type__c: dayData.Travel_Type__c,
                Working_Hours_For_Expense__c: dayData.Working_Hours_For_Expense__c || 0,
                // Distance_Travelled__c: dayData.Distance_Travelled__c || 0,
                Purpose_of_Visit__c: dayData.Purpose_of_Visit__c,
                isSelected: false,
                Id: dayData.Id,
                isCollapsed: true,
                dayclass: 'slds-m-bottom_x-small expense-day-modern',
                dayheaderClass: 'blueColor day-header slds-grid slds-grid_align-spread slds-p-around_small',
                isCheckBoxDisabled: false,
                iconName: 'utility:chevronright',
                lineItems: lineItemsForDay.length > 0
                    ? lineItemsForDay
                    : this.createDefaultExpenseItems(dateStr, dayData),
                totalExpense: lineItemsForDay.reduce((sum, item) => sum + (item.Amount__c || 0), 0)
            };
        });

        // Reverse for descending order
        enrichedDays.sort((a, b) => new Date(b.Date__c) - new Date(a.Date__c));

        this.days = enrichedDays;
        this.getGrandTotal();
        this.showSubmitAndApproveButton();
        this.disableDayWiseCheckBox();
    }
    calculateTALimit(value) {
        if (value === 'Bike') {
            return this.dailylimitBike;
        }
        else if (value === 'Car') {
            return this.dailylimitCar;
        } else if (value === 'Autorishaw') {
            return this.dailylimitAuto;
        } else {
            return null;
        }
    }

    createDefaultExpenseItems(date, dayData) {
        try {
            const travelType = dayData.Travel_Type__c || '';

            const uidTA = 'TA_' + this.generateUUID();
            const uidDA = 'DA_' + this.generateUUID();
            let dailyKMLimit = 0
            let taAmount = 0;
            let daAmount = 0;
            let kMtravelled = 0;
            const hours = dayData.Working_Hours_For_Expense__c || 0;
            kMtravelled = dayData.KMs_Travelled__c || 0;
            if (dayData.Mode_of_Transport__c == 'Bike') {
                taAmount = this.perKMChargeBike * kMtravelled;
            }
            else if (dayData.Mode_of_Transport__c == 'Car') {
                taAmount = this.perKMChargeCar * kMtravelled;
            }

            if (travelType == 'Field - Other State') {
                daAmount = this.daAmountUP;

            }
            else if (travelType == 'In Office' || travelType == 'Field - Home District') {
                daAmount = this.daAmountHQ;

            }
            else if (travelType == 'Field - Other District') {
                daAmount = this.daAmountDIS;

            }
            let isDARemarksMandate = this.eligibilities.Mandatory_Remarks_File_Types__c &&
                this.eligibilities.Mandatory_Remarks_File_Types__c.split(';').includes('DA') ? true : false;

            let isTARemakrsMandate = this.eligibilities.Mandatory_Remarks_File_Types__c &&
                this.eligibilities.Mandatory_Remarks_File_Types__c.split(';').includes('TA') ? true : false;

            let isDAFileMandate = this.eligibilities.Mandatory_File_Expense_Types__c &&
                this.eligibilities.Mandatory_File_Expense_Types__c.split(';').includes('DA') ? true : false;

            let isTAFileMandate = this.eligibilities.Mandatory_File_Expense_Types__c &&
                this.eligibilities.Mandatory_File_Expense_Types__c.split(';').includes('TA') ? true : false;

            let customTAClass = 'slds-size_1-of-4 slds-p-horizontal_small';
            if (isTARemakrsMandate && this.showLimitFields) {
                customTAClass = 'slds-size_1-of-6 slds-p-horizontal_small';
            }
            else if ((isTARemakrsMandate && !this.showLimitFields) || (!isTARemakrsMandate && this.showLimitFields)) {
                customTAClass = 'slds-size_1-of-5 slds-p-horizontal_small';
            }
            else {
                customTAClass = 'slds-size_1-of-4 slds-p-horizontal_small';
            }
            let customDAClass = this.isDesktop ? isDARemarksMandate ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';

            // TA Item
            const taItem = {
                sObjectType: 'Expense_Line_Item__c',
                Id: null,
                localId__c: uidTA,
                fileUId: uidTA,
                fileRecordId: this.OwnerId,
                Approval_Status__c: 'Not Submitted',
                isDisabled: this.checkIsNewTransportCarBike(dayData),
                customClass: 'legend-colorBlock notsubmitted-exp',
                iseditEnabled: false,
                expenseTypeId: 'Expense_Type' + uidTA,
                travelModeId: dayData.Mode_of_Transport__c + '' + uidTA,
                Expense_Date__c: date,
                Travel_Type__c: travelType || '',
                Expense_Type__c: 'TA',
                Travel_Mode__c: dayData.Mode_of_Transport__c,
                System_Calculated_Amount__c: 0,
                City_Name__c: '',
                Working_Hours__c: dayData.Working_Hours_For_Expense__c || 0,
                Total_KM__c: dayData.KMs_Travelled__c || 0,
                Amount__c: taAmount,
                Remarks__c: '',
                Expense__c: '',
                Daily_Log__c: dayData.Id,
                Food_Type__c: '',
                Calculated_KM__c: dayData.KMs_Travelled__c || 0,
                lodging_Limit__c: 0,
                TA_Limit__c: this.calculateTALimit(dayData.Mode_of_Transport__c),
                Local_Conveyance_Limit__c: 0,
                customClassLine: this.isDesktop ? customTAClass : 'slds-size_1-of-2 slds-p-horizontal_small',
                fileUploaded: false,
                expenseTypes: this.getExpenseTypePicklistValues(dayData),
                travelModes: this.getTravelModePicklistValues(dayData),
                isTA: true,
                isTransportCarBike: this.checkIsNewTransportCarBike(dayData),
                isTransportNotBikeCar: this.checkIsNewTransportNotBikeCar(dayData),
                isDA: false,
                isLodging: false,
                isLocalConveyance: false,
                isOtherExpense: false,
                showDropdown: false,
                isCityReadOnly: false,
                remarksMandatory: isTARemakrsMandate,
                fileUploadMandatory: isTAFileMandate,
                showFoodExpense: false,
                Lodging_Food_Expense_Limit__c: 0,
                isLodgingFoodExpense: false,
                disableExpenseType: true,
                isShowDeleteButton: false,
                disableDaAmout: true,
                isSelected: false,
                isCheckboxDisabled: false,
                Is_Updated__c: false,
                isShowModeTransport: false,
                isDailyKmDisabled: dailyKMLimit != 0 ? true : false,
                isDisabled: false
            };

            // DA Item
            const daItem = {
                ...taItem,
                localId__c: uidDA,
                fileUId: uidDA,
                Amount__c: daAmount,
                DA_Limit__c: daAmount,
                expenseTypeId: 'Expense_Type' + uidDA,
                travelModeId: 'Travel_Mode' + uidDA,
                Travel_Mode__c: '',
                Expense_Type__c: 'DA',
                isTA: false,
                isDA: true,
                customClassLine: customDAClass,
                remarksMandatory: isDARemarksMandate,
                fileUploadMandatory: isDAFileMandate,
                disableDaAmout: true,
                isSelected: false,
            };

            return [taItem, daItem];
        } catch (error) {
            console.error(error.message);
        }
    }

    createEmptyLineItem(date, dayData) {
        var expenseTypes = [];
        var travelModes = [];
        const travelType = dayData.Travel_Type__c || '';

        if (travelType == 'Field - Other State' || travelType == 'Field - Other District') {

            //Getting up contry Expense types
            let selectedexpenseTypes = this.eligibilities.Expense_Type_UC__c
                ? this.eligibilities.Expense_Type_UC__c.split(';')
                : [];
            // Filter from allTravelModes where value matches
            expenseTypes = this.expenseTypes.filter(mode =>
                selectedexpenseTypes.includes(mode.value) && mode.value !== 'DA'
            );

            //Getting up contry travel types
            let selectedModes = this.eligibilities.Travel_Mode_UC__c
                ? this.eligibilities.Travel_Mode_UC__c.split(';')
                : [];

            // Filter from allTravelModes where value matches
            travelModes = this.travelModes.filter(mode =>
                selectedModes.includes(mode.value)
            );

        }
        else if (travelType == 'In Office' || travelType == 'Field - Home District') {

            //Getting up contry Expense types
            let selectedexpenseTypes = this.eligibilities.Expense_Type_HQ__c
                ? this.eligibilities.Expense_Type_HQ__c.split(';')
                : [];

            // Filter from allTravelModes where value matches
            expenseTypes = this.expenseTypes.filter(mode =>
                selectedexpenseTypes.includes(mode.value) && mode.value !== 'DA'
            );



            //Getting up contry travel types
            let selectedModes = this.eligibilities.Travel_Mode_HQ__c
                ? this.eligibilities.Travel_Mode_HQ__c.split(';')
                : [];

            // Filter from allTravelModes where value matches
            travelModes = this.travelModes.filter(mode =>
                selectedModes.includes(mode.value)
            );

        }
        // Add "Select option" at the beginning
        travelModes = [{ label: 'Select option', value: '' }, ...travelModes];
        expenseTypes = [{ label: 'Select option', value: '' }, ...expenseTypes];
        const uid = this.generateUUID();
        return {
            sObjectType: 'Expense_Line_Item__c',
            Id: null,
            localId__c: uid,
            fileUId: uid,
            fileRecordId: this.OwnerId,
            Approval_Status__c: 'Not Submitted',
            customClass: 'legend-colorBlock notsubmitted-exp',
            iseditEnabled: false,
            customClassLine: this.isDesktop ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small',
            expenseTypeId: 'Expense_Type' + uid,
            travelModeId: 'Travel_Mode' + uid,
            Expense_Date__c: date,
            Travel_Type__c: travelType,
            Expense_Type__c: '',
            Travel_Mode__c: '',
            System_Calculated_Amount__c: 0,
            City_Name__c: '',
            Working_Hours__c: dayData.Working_Hours_For_Expense__c || 0,
            Total_KM__c: '',
            Amount__c: '',
            Remarks__c: '',
            Expense__c: '',
            Daily_Log__c: dayData.Id,
            Food_Type__c: '',
            lodging_Limit__c: 0,
            Local_Conveyance_Limit__c: 0,
            fileUploaded: false,
            expenseTypes: expenseTypes,
            travelModes: travelModes,
            isTA: false,
            isTransportCarBike: false,
            isTransportNotBikeCar: false,
            isDA: false,
            isLodging: false,
            isLocalConveyance: false,
            isOtherExpense: false,
            showDropdown: false,
            isCityReadOnly: false,
            remarksMandatory: false,
            fileUploadMandatory: false,
            showFoodExpense: false,
            Lodging_Food_Expense_Limit__c: 0,
            isLodgingFoodExpense: false,
            disableExpenseType: false,
            disableDaAmout: false,
            isSelected: false,
            isShowDeleteButton: true,
            isCheckboxDisabled: false,
            Is_Updated__c: false,
            isShowModeTransport: false,
            isDisabled: false
        };
    }
    toggleDayCollapse(event) {
        const date = event.target.dataset.date;

        this.days = this.days.map((day, index) => {
            if (day.Date__c === date) {
                day.isCollapsed = !day.isCollapsed;
                day.iconName = day.isCollapsed ? 'utility:chevronright' : 'utility:chevrondown';
            }

            // Apply padding only for the last day and only when expanded
            if (index === this.days.length - 1 && !day.isCollapsed) {
                day.dayclass = 'slds-m-bottom_x-small expense-day-modern pb-100';
            } else {
                day.dayclass = 'slds-m-bottom_x-small expense-day-modern';
            }

            return day;
        });

        // Wait for DOM re-render
        Promise.resolve().then(() => {
            this.validateAmounts();
        });
    }


    validateAmounts() {
        const inputs = this.template.querySelectorAll('[data-id="Amount"]');
        inputs.forEach(input => input.reportValidity());
    }

    addLineItem(event) {

        const date = event.target.dataset.date;
        if (this.OpenedByOwner) {
            let backdatedEntryLimit = this.expenseBackDayEntry || 0;  // e.g., 5 or 6

            // Convert strings → Date objects
            const selectedDate = new Date(date);
            const today = new Date();

            // Remove time portion for accurate day difference
            selectedDate.setHours(0, 0, 0, 0);
            today.setHours(0, 0, 0, 0);

            // Calculate difference in days
            const diffInMs = today - selectedDate;
            const diffInDays = diffInMs / (1000 * 60 * 60 * 24);

            if (diffInDays > backdatedEntryLimit || diffInDays < 0) {
                this.showToast('Error', `You can only enter expenses up to ${backdatedEntryLimit} days back.`, "error");
                return;
            }
        }

        this.days = this.days.map(day => {
            if (day.Date__c === date) {
                day.lineItems.push(this.createEmptyLineItem(date, day || {}));
            }
            return day;
        });
        this.showSubmitAndApproveButton();
        this.disableDayWiseCheckBox();
    }

    //Remove Row
    removeLineItem(event) {
        const date = event.target.dataset.date;
        const localId = event.target.dataset.localid;

        if (this.OpenedByOwner) {
            let backdatedEntryLimit = this.expenseBackDayEntry || 0;  // e.g., 5 or 6

            // Convert strings → Date objects
            const selectedDate = new Date(date);
            const today = new Date();

            // Remove time portion for accurate day difference
            selectedDate.setHours(0, 0, 0, 0);
            today.setHours(0, 0, 0, 0);

            // Calculate difference in days
            const diffInMs = today - selectedDate;
            const diffInDays = diffInMs / (1000 * 60 * 60 * 24);

            if (diffInDays > backdatedEntryLimit || diffInDays < 0) {
                this.showToast('Error', `You can only enter expenses up to ${backdatedEntryLimit} days back.`, "error");
                return;
            }
        }

        this.days = this.days.map(day => {
            if (day.Date__c === date) {
                // Find the line item to remove
                const removedItem = day.lineItems.find(item => item.localId__c === localId);

                // If it has a Salesforce Id, add to DeleteExpLine
                if (removedItem && removedItem.Id) {
                    if (!this.DeleteExpLine) {
                        this.DeleteExpLine = [];
                    }
                    this.DeleteExpLine.push(removedItem.Id);
                }

                // Remove the item
                day.lineItems = day.lineItems.filter(item => item.localId__c !== localId);

                // If no line items left, add a fresh empty one
                if (day.lineItems.length === 0) {
                    day.lineItems.push(this.createEmptyLineItem(date, day || {}));
                }
            }
            return day;
        });

        this.getGrandTotal();
        this.showSubmitAndApproveButton();
        this.disableDayWiseCheckBox();
    }

    handleExpenseTypeChange(event) { /* CHANGE IN expense line item type*/
        const selectedExType = event.target.value;
        const expId = event.target.dataset.id;
        const localId = event.target.dataset.localid;
        const date = event.target.dataset.date;

        // Find the day containing the line item using the localId
        const dayData = this.days.find(day => day.lineItems.some(item => item.localId__c === localId));
        const lineItem = dayData.lineItems.find(item => item.localId__c === localId);
        lineItem.Expense_Type__c = selectedExType;

        // Reset values
        lineItem.Amount__c = null;
        lineItem.Travel_Mode__c = '';
        lineItem.Total_KM__c = null;
        lineItem.isTA = false;
        lineItem.isDA = false;
        lineItem.isLodging = false;
        lineItem.isOtherExpense = false;
        lineItem.isTransportCarBike = false;
        lineItem.isTransportNotBikeCar = false;
        lineItem.remarksMandatory = false;
        lineItem.isLocalConveyance = false;
        lineItem.fileUploadMandatory = false;
        lineItem.showFoodExpense = false;
        lineItem.Lodging_Food_Expense_Limit__c = 0;
        lineItem.isLodgingFoodExpense = false;
        lineItem.isMobileExpense = false;
        lineItem.customClassLine = this.isDesktop ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
        lineItem.disableExpenseType = false;
        lineItem.isShowModeTransport = false;
        lineItem.isDisabled = false;





        if (this.OpenedByOwner) {
            let backdatedEntryLimit = this.expenseBackDayEntry || 0;  // e.g., 5 or 6

            // Convert strings → Date objects
            const selectedDate = new Date(date);
            const today = new Date();

            // Remove time portion for accurate day difference
            selectedDate.setHours(0, 0, 0, 0);
            today.setHours(0, 0, 0, 0);

            // Calculate difference in days
            const diffInMs = today - selectedDate;
            const diffInDays = diffInMs / (1000 * 60 * 60 * 24);

            if (diffInDays > backdatedEntryLimit || diffInDays < 0) {
                this.showToast('Error', `You can only enter expenses up to ${backdatedEntryLimit} days back.`, "error");
                const inputField = this.template.querySelector(`[data-id="${expId}"]`);
                if (inputField) {
                    inputField.value = '';
                    lineItem.Expense_Type__c = '';
                }
                return;
            }
        }

        // Skip duplicate validation for TA
        const isDuplicate = selectedExType !== 'TA' && selectedExType !== 'Transport Conveyance' && dayData.lineItems.some(item =>
            item.localId__c !== localId &&
            item.Expense_Type__c === selectedExType &&
            item.Expense_Date__c === date
        );


        if (isDuplicate) {
            const inputField = this.template.querySelector(`[data-id="${expId}"]`);
            if (inputField) {
                inputField.value = '';
                lineItem.Expense_Type__c = '';
            }
            this.showToast('Duplicate Expense Type', `Expense type "${selectedExType}" is already selected for ${dayData.Date__c}`, "error");
            return;
        }

        const isDuplicateLodging = dayData.lineItems.some(item =>
            item.localId__c !== localId &&
            item.Expense_Date__c === date &&
            (
                (selectedExType === 'Lodging' && item.Expense_Type__c === 'Lodging + Food') ||
                (selectedExType === 'Lodging + Food' && item.Expense_Type__c === 'Lodging')
            )
        );

        if (isDuplicateLodging) {
            const inputField = this.template.querySelector(`[data-id="${expId}"]`);
            if (inputField) {
                inputField.value = '';
                lineItem.Expense_Type__c = '';
            }
            this.showToast(
                'Duplicate Expense Type',
                `"${selectedExType}" cannot be selected for ${dayData.Date__c} because a Lodging expense type already exists.`,
                "error"
            );
            return;
        }



        // Show Travel Mode and City fields if Expense Type is "Travel"
        if (selectedExType === 'Accommodation') {
            lineItem.isLodging = true;
            lineItem.lodging_Limit__c = this.lodgingLimit || '';
        }
        else if (selectedExType === 'Local Conveyance') {
            lineItem.Local_Conveyance_Limit__c = this.localConveyanceAmont ? this.localConveyanceAmont : null;
            lineItem.isLocalConveyance = true;
        }
        else if (['Other/MISC', 'Courier Charges', 'Food', 'Food Allowance', 'Printing Charges',
            'Stationary Charges'].includes(selectedExType)) {
            lineItem.isOtherExpense = true;
        }
        else if (selectedExType === 'Mobile Charges') {
            lineItem.isMobileExpense = true;
            lineItem.Amount__c = this.mobileExpenseLimit;
        }
        else if (selectedExType === 'Transport Conveyance') {
            lineItem.isShowModeTransport = true;
        } else if (selectedExType === 'TA') {
            lineItem.isTA = true;

        }

        if (this.eligibilities.Mandatory_Remarks_File_Types__c &&
            this.eligibilities.Mandatory_Remarks_File_Types__c.split(';').includes(selectedExType)
        ) {
            lineItem.remarksMandatory = true;
        }

        if (this.eligibilities.Mandatory_File_Expense_Types__c &&
            this.eligibilities.Mandatory_File_Expense_Types__c.split(';').includes(selectedExType)
        ) {
            lineItem.fileUploadMandatory = true;
        }

        lineItem.customClassLine = this.getItemClass(lineItem);

        this.getGrandTotal();
    }

    handleTravelModeChange(event) {
        const field = event.currentTarget.dataset.name;
        const localId = event.target.dataset.localid;
        const expId = event.target.dataset.id;
        const value = event.currentTarget.value;
        const date = event.target.dataset.date;


        // Find the day containing the line item using the localId
        const dayData = this.days.find(day =>
            day.lineItems.some(item => item.localId__c === localId)
        );
        if (!dayData) return;

        const lineItem = dayData.lineItems.find(item => item.localId__c === localId);
        // Reset flags
        lineItem.Amount__c = null;
        lineItem.Travel_Mode__c = event.detail.value;
        if (event.detail.value === 'Bike' || event.detail.value === 'Car') {
            lineItem.isTransportCarBike = true;
            lineItem.isDisabled = false;
            if (event.detail.value === 'Bike') { lineItem.TA_Limit__c = this.dailylimitBike; }
            else {
                lineItem.TA_Limit__c = this.dailylimitCar;
            }
        } else {
            lineItem.isTransportCarBike = false;
            lineItem.isDisabled = false;
            if (event.detail.value === 'Autorishaw') {
                lineItem.TA_Limit__c = this.dailylimitAuto;
            } else {
                lineItem.TA_Limit__c = null;
            }
        }
        console.log('dayData.lineItems ' + JSON.stringify(dayData.lineItems));

        // Skip duplicate validation for TA
        const isDuplicate = dayData.lineItems.some(item =>
        (item.localId__c != localId &&
            item.Travel_Mode__c === value &&
            item.Expense_Date__c === date)
        );

        if (isDuplicate) {
            const inputField = this.template.querySelector(`[data-id="${expId}"]`);
            if (inputField) {
                inputField.value = '';
                lineItem.Travel_Mode__c = '';
            }
            this.showToast('Duplicate Travel Mode1', `Travel Mode "${value}" is already selected for ${dayData.Date__c}`, "error");
            return;
        }

        lineItem.isOtherExpense = false;

    }

    //Input field change
    handleInputChange(event) {
        const field = event.currentTarget.dataset.name;
        const value = event.target.value;
        const localId = event.currentTarget.dataset.localid;
        const dayData = this.days.find(day => day.lineItems.some(item => item.localId__c === localId));
        const lineItem = dayData.lineItems.find(item => item.localId__c === localId);

        if (field === "Amount") {
            lineItem.Amount__c = value;
            this.getGrandTotal();
        }
        else if (field === "Remarks") {
            lineItem.Remarks__c = value;
        }
        else if (field === "Total_KM") {
            lineItem.Total_KM__c = value;
            lineItem.Calculated_KM__c = value;

            if (lineItem.Travel_Mode__c === 'Car') {
                lineItem.Amount__c = value * this.perKMChargeCar;
            }
            else if (lineItem.Travel_Mode__c === 'Bike') {
                lineItem.Amount__c = value * this.perKMChargeBike;
            }

            this.getGrandTotal();

        }


    }

    //Expense Input chage
    hadleExpenseCommentsChange(event) {
        const value = event.target.value;
        this.approvalComments = value;
    }

    handleSectionToggle(event) {
        // This will automatically track open/close
        this.activeSection = event.detail.openSections;
    }

    getGrandTotal() {
        try {
            let grandTotal = 0;
            let carKm = 0;
            let bikeKm = 0;
            let autoAmount = 0;
            // Loop through each day to calculate the total expense
            this.days = this.days.map(day => {
                let dayTotal = 0;


                // If there are lineItems, sum their amounts
                if (day.lineItems) {

                    dayTotal = day.lineItems.reduce((sum, item) => {

                        return sum + (Math.round(item.Amount__c * 100) / 100 || 0);
                    }, 0);


                    day.lineItems.forEach(item => {
                        const km = Number(item.Total_KM__c) || 0;
                        const amount = Number(item.Amount__c) || 0;
                        switch (item.Travel_Mode__c) {
                            case 'Car':
                                carKm += km;
                                break;

                            case 'Bike':
                                bikeKm += km;
                                break;

                            case 'Autorishaw':
                                autoAmount += amount;
                                break;
                        }
                    });

                }
                // Set the total for the day
                day.totalExpense = Math.round(dayTotal * 100) / 100;
                grandTotal += dayTotal;

                return day;
            });
            this.totalCarKM = carKm;
            this.totalBikeKM = bikeKm;
            this.totalAutoAmt = autoAmount;
            // Set the grand total, rounded to 2 decimal places
            this.grandTotal = Math.round(grandTotal * 100) / 100;
        } catch (error) {
            console.error('grandtotal' + error.message);
        }
    }

    showSubmitAndApproveButton() {
        // Reset flags
        this.OpenedByOwner = false;
        this.OpenedByApprover = false;
        this.showLimitFields = false;
        this.showSubmitforApproval = false;

        // Case 1: Opened by Owner/Submitter
        if (!this.recordId || !this.expense || this.loggedInUser.Id === this.expense.OwnerId) {
            this.OpenedByOwner = true;

            // Check if at least one item is eligible for submission
            this.showSubmitforApproval = this.days.some(day =>
                day.lineItems.some(item =>
                    item.Approval_Status__c !== 'Pending' &&
                    item.Approval_Status__c !== 'Level 1 Approved' &&
                    item.Approval_Status__c !== 'Level 2 Approved' &&
                    item.Approval_Status__c !== 'HR Approved' &&
                    item.Approval_Status__c !== 'Approved'
                )
            );

            if (this.OpenedByOwner) {
                this.expenseBackDayEntry = this.loggedInUser.Expense_Back_Day_Entry_Limit__c;
            }
            return; // Stop here since only Owner is allowed in this scenario
        }

        // Case 2: Opened by Approver
        const isApprover = this.days.some(day =>
            day.lineItems.some(item => this.isUserApproverForItem(this.expense, item, this.loggedInUser.Id))
        );

        if (isApprover) {
            this.OpenedByApprover = true;
        }

        if (this.loggedInUser.Id !== this.expense.OwnerId) {
            this.showLimitFields = true;
        }
    }

    isUserApproverForItem(expense, item, loggedInUserId) {
        const status = item.Approval_Status__c;

        // Level 1 Approver
        if (expense.Expense_Approver_L1__c === loggedInUserId && status === 'Pending') {
            return true;
        }

        /*   // Level 2 Approver
        if (expense.Expense_Approver_L2__c === loggedInUserId &&
        (status === 'Level 1 Approved' ||
        (!expense.Expense_Approver_L1__c && status === 'Pending'))) {
        return true;
        }
        
        // Finance Approver (Level 3)
        if (expense.Expense_Finance_Department_Approver__c === loggedInUserId &&
        (status === 'Level 2 Approved' ||
        (!expense.Expense_Approver_L2__c && expense.Expense_Approver_L1__c && status === 'Level 1 Approved') ||
        (!expense.Expense_Approver_L1__c && !expense.Expense_Approver_L2__c && status === 'Pending'))) {
        return true;
        }
        
        //If Opened by Admin 
        if(this.loggedInUser.isAdmin__c && (status=='Pending' || status === 'Level 1 Approved' || status === 'Level 2 Approved'))
        {
        return true;
        }*/

        return false;
    }



    /**==============Select Checkbox ===========**/
    handleItemCheckbox(event) {
        const localId = event.target.dataset.localid;
        const checked = event.target.checked;

        // Find the day that has this line item
        const dayData = this.days.find(day =>
            day.lineItems.some(item => item.localId__c === localId)
        );

        if (dayData) {
            // Find the exact line item
            const lineItem = dayData.lineItems.find(item => item.localId__c === localId);
            if (lineItem) {
                lineItem.isSelected = checked;
            }

            // Update the day's select-all based on children
            const allSelected = dayData.lineItems.every(item => item.isSelected);
            dayData.isSelected = allSelected;
        }

        // Force re-render
        this.days = [...this.days];
        this.updateButtonState();
    }
    handleDayCheckbox(event) {
        const date = event.target.dataset.date;
        const checked = event.target.checked;

        this.days = this.days.map(day => {
            if (day.Date__c === date) {
                // Update day-level selection
                day.isSelected = checked;

                // Update all line items under this day (respect isCheckboxDisabled)
                day.lineItems = day.lineItems.map(item => ({
                    ...item,
                    isSelected: item.isCheckboxDisabled ? item.isSelected : checked
                }));
            }
            return day;
        });
        this.updateButtonState();
    }
    handleAllCheckbox(event) {
        const checked = event.target.checked; // global select all

        this.days = this.days.map(day => {
            // Only update if the day itself is NOT disabled
            if (!day.isCheckBoxDisabled) {
                // Update day selection
                day.isSelected = checked;

                // Update its line items (only those not disabled)
                day.lineItems = day.lineItems.map(item => ({
                    ...item,
                    isSelected: item.isCheckboxDisabled ? item.isSelected : checked,
                }));
            }

            return day;
        });

        this.updateButtonState();
    }
    updateButtonState() {
        // Flatten all lineItems and check if any selected
        const anySelected = this.days.some(day =>
            day.lineItems.some(item => item.isSelected)
        );

        this.disableButtons = !anySelected;
    }

    /**==========Save and Validate ================**/
    validateFields() {
        let isAllValid = true;
        // Flatten all lineItems across days
        console.log('expItems' + JSON.stringify(this.days.lineItems));
        const expItems = this.days.flatMap(day => day.lineItems);
        for (let i = 0; i < expItems.length; i++) {
            if (expItems[i].Expense_Type__c) {
                /*     if(expItems[i].Expense_Type__c =='Lodging' )
                {
                    isAllValid = false;
                    this.showFieldError('city'); 
                    this.showToast('Error',  `Please select a City for Lodging expense on ${expItems[i].Expense_Date__c}.`, 'error');
                    return isAllValid;
                }*/

                if (['Other/MISC', 'Courier Charges', 'Mobile Charges', 'Local Conveyance', 'Lodging', 'Food Allowance', 'Printing Charges',
                    'Stationary Charges'].includes(expItems[i].Expense_Type__c) && !expItems[i].Amount__c) {
                    isAllValid = false;
                    this.showFieldError('Amount');
                    this.showToast('Error', `Please enter Amount for ${expItems[i].Expense_Type__c} expense on ${expItems[i].Expense_Date__c}.`, 'error');
                    return isAllValid;
                }
                if (expItems[i].remarksMandatory && !expItems[i].Remarks__c) {
                    isAllValid = false;
                    this.showFieldError('Remarks__c');
                    this.showToast('Error', `Please enter Remarks for ${expItems[i].Expense_Type__c} expense on ${expItems[i].Expense_Date__c}.`, 'error');
                    return isAllValid;
                }
            }
        }
        return isAllValid;
    }
    doSave() {
        try {
            if (this.validateFields()) {
                // Flatten all line items with their parent day index
                const allItems = this.days.flatMap((day, dayIndex) =>
                    day.lineItems.map(item => ({ ...item, dayIndex }))
                );

                for (let i = 0; i < allItems.length; i++) {
                    const item = allItems[i];
                    console.log('item' + JSON.stringify(item));
                    if (item.Expense_Type__c) {

                        if ((!item.Amount__c || item.Amount__c === 0) && item.Expense_Type__c !== 'DA') {
                            item.Amount__c = null;

                            this.showToast(
                                'Error',
                                `Please enter Amount for ${item.Expense_Type__c} expense on ${item.Expense_Date__c}.`,
                                'error'
                            );

                            // Update back only the affected day’s line items
                            const days = [...this.days];
                            days[item.dayIndex].lineItems = [
                                ...days[item.dayIndex].lineItems
                            ];
                            this.days = days;
                            return; // stop at first error
                        }
                    }
                }
                this.isLoading = true;
                // Call file validation
                this.validateFilesForItems().then((isValid) => {
                    this.isLoading = false;
                    if (isValid) {
                        if (this.submitforApproval == true || this.approveRecord == true || this.rejectRecord == true) {
                            this.getApprovalSummary(allItems);
                            this.showBody = !this.isDesktop ? false : true;
                            this.isShowApprovalPopUp = true;
                            if (!this.isDesktop) {
                                setTimeout(() => {
                                    window.scrollTo({
                                        top: 0,
                                        behavior: 'smooth'
                                    });
                                }, 0);
                            }

                        }
                        else {
                            this.createExpenses();
                        }

                    } else {
                        this.isButtonDisabled = false; // re-enable if failed
                        this.submitforApproval = false;
                        this.approveRecord = false;
                        this.rejectRecord = false;
                        this.isShowApprovalPopUp = false;

                        this.showBody = true;
                    }
                });
            }
            else {
                this.submitforApproval = false;
                this.approveRecord = false;
                this.rejectRecord = false;
            }
        } catch (error) {
            this.isLoading = false;
            console.error('y'+error.message);
           this.showToast(
                    'Error',
                    'error.message',
                    'error'
                );  
        }
    }
    async validateFilesForItems() {
        try {
            // Build payload only for items having Expense_Type__c
            const itemsToCheck = this.days.flatMap((day, dayIndex) =>
                day.lineItems
                    .filter(item => item.Expense_Type__c && item.fileUploadMandatory)
                    .map((item, i) => ({
                        uniqueKey: `${dayIndex}-${i}`,
                        Id: item.Id || null,
                        localId__c: item.localId__c || null,
                        Expense_Type__c: item.Expense_Type__c,
                        Expense_Date__c: item.Expense_Date__c
                    }))
            );

            const results = await validateFiles({ itemsToCheck });

            let missingDatesSet = new Set();

            for (let key in results) {
                if (!results[key]) {
                    const [dayIndex, itemIndex] = key.split('-').map(Number);
                    const item = this.days[dayIndex].lineItems[itemIndex];

                    // Add date to Set (automatically keeps only unique values)
                    missingDatesSet.add(item.Expense_Date__c);
                }
            }

            // Convert Set back to array
            let missingDates = Array.from(missingDatesSet);

            if (missingDates.length > 0) {
                this.showToast(
                    'Error',
                    `Please upload bill/receipts before saving expense on ${missingDates.join(', ')}`,
                    'error'
                );
                return false; // stop save
            }


            return true;
        } catch (err) {
            console.error('File validation error', err);
            this.showToast('Error', 'Unable to validate files. Please try again.', 'error');
            return false;
        }
    }
    createExpenses() {

        this.isShowApprovalPopUp = false;
        this.showBody = true;
        this.showDoneButton = false;
        let exp = this.expense;
        let loggedInUserId = this.loggedInUser.Id;

        // Flatten all line items with their parent day index
        const allItems = this.days.flatMap((day, dayIndex) =>
            day.lineItems
                .filter(item => item.Expense_Type__c) // keep only items with value
                .map(item => {
                    let updatedItem = { ...item, dayIndex };

                    if (item.isSelected) {
                        updatedItem.Is_Updated__c = true;
                        // Case 1: Submit for Approval
                        if (this.submitforApproval) {
                            updatedItem.Approval_Status__c = 'Pending';
                        }
                        // Case 2: Approve
                        else if (this.approveRecord) {
                            if (exp.Expense_Approver_L1__c === loggedInUserId) {
                                updatedItem.Approval_Status__c = 'Level 1 Approved';
                            }
                            /*  else if (exp.Expense_Approver_L2__c === loggedInUserId) {
                                updatedItem.Approval_Status__c = 'Level 2 Approved';
                            } else if (exp.Expense_Finance_Department_Approver__c === loggedInUserId) {
                                updatedItem.Approval_Status__c = 'HR Approved';
                            }
                            else if(this.loggedInUser.isAdmin__c){
                                if(item.Approval_Status__c == 'Pending' && exp.Expense_Approver_L1__c != null){
                                    updatedItem.Approval_Status__c = 'Level 1 Approved';
                                }
                                else if(item.Approval_Status__c == 'Pending' && 
                                    exp.Expense_Approver_L1__c == null && exp.Expense_Approver_L2__c != null 
                                ){
                                    updatedItem.Approval_Status__c = 'Level 2 Approved';
                                }
                                else if(item.Approval_Status__c == 'Pending' && 
                                    exp.Expense_Approver_L1__c == null && exp.Expense_Approver_L2__c == null ){
                                    updatedItem.Approval_Status__c = 'HR Approved';
                                }
                                else if(item.Approval_Status__c == 'Level 1 Approved' && exp.Expense_Approver_L2__c != null ) {
                                    updatedItem.Approval_Status__c = 'Level 2 Approved';
                                }
                                else if((item.Approval_Status__c == 'Level 1 Approved' && exp.Expense_Approver_L2__c == null) ||
                                    (item.Approval_Status__c == 'Level 2 Approved' )
                                ){
                                    updatedItem.Approval_Status__c = 'HR Approved';
                                }
                
                            }*/
                        }
                        // Case 3: Reject
                        else if (this.rejectRecord) {
                            if (exp.Expense_Approver_L1__c === loggedInUserId) {
                                updatedItem.Approval_Status__c = 'Level 1 Rejected';
                            }

                        }
                        // Case 4: If none of the flags true => do nothing (skip update)
                    }

                    return updatedItem;
                })
        );

        this.isLoading = true;
        save({
            expense: this.expense,
            expenseItems: allItems,
            delitems: this.DeleteExpLine,
            submitforApproval: this.submitforApproval,
            approveRecord: this.approveRecord,
            rejectRecord: this.rejectRecord,
            approvalComments: this.approvalComments
        })
            .then(data => {

                let redirect = true;
                let successmessage = 'Expense saved successfully!';
                if (this.submitforApproval) {
                    redirect = true;
                    successmessage = 'Expense saved and submitted successfully!';
                } else if (this.approveRecord) {
                    redirect = false;
                    successmessage = 'Expense saved and approved successfully. Please click on Done!';
                } else if (this.rejectRecord) {
                    redirect = false;
                    successmessage = 'Expense rejected successfully. Please click on Done!';
                }
                // Reset action flags (so next save is clean)
                this.submitforApproval = false;
                this.approveRecord = false;
                this.rejectRecord = false;
                this.isButtonDisabled = false;
                this.isLoading = false;
                this.showToast('Success', successmessage, 'success');
                let updatedComments = data.expenseCommnents || '';
                this.commentHistoryList = this.parseCommentHistory(updatedComments);
                this.showComments = this.commentHistoryList.length > 0 ? true : false;

                if (redirect) {
                    this.dispatchToAura('Done', data.expenseId);
                }
                else {
                    this.showDoneButton = true;
                    this.expense.Id = data.expenseId;
                    this.lineItems = data.lineItems;
                    this.approvalComments = '';
                    this.populateDays();
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error;
                console.error(JSON.stringify(error));
            });
    }

    getApprovalSummary(allItems) {
        // Step: Extract unique selected dates and amounts
        const selectedItems = allItems.filter(item => item.isSelected);

        if (selectedItems.length > 0) {
            // Get unique dates
            const uniqueDates = [...new Set(selectedItems.map(item => item.Expense_Date__c))];

            // Find min and max dates
            const minDate = uniqueDates.reduce((a, b) => (a < b ? a : b));
            const maxDate = uniqueDates.reduce((a, b) => (a > b ? a : b));

            // Build dateRange string
            this.periodName = minDate === maxDate ? minDate : `${minDate} to ${maxDate}`;

            // Total amount
            this.selectedAmount = selectedItems.reduce((sum, item) => {
                return sum + (item.Amount__c ? parseFloat(item.Amount__c) : 0);
            }, 0);

            // No of unique days
            this.selectedDays = uniqueDates.length;
        } else {
            this.periodName = null;
            this.selectedAmount = 0;
            this.selectedDays = 0;
        }

    }



    closeExpense() {
        if (this.expense.Id) {
            this.dispatchToAura('Done', this.expense.Id);
        }
        else {
            this.dispatchToAura('Cancel', null);
        }
    }
    gotoRecord() {
        this.dispatchToAura('Done', this.expense.Id);
    }

    /**==========Submit and Approve ================**/
    saveAndSubmitExpense() {

        if (this.validateSubmitAndApprove()) {
            this.submitforApproval = true;
            this.approvalButtonLabel = 'Submit';
            this.approvalHeader = 'Submit Expenses';
            this.doSave();
        } else {
            this.showToast('Error', 'Please select Expenses to Submit', 'error');
        }
    }
    saveAndApprove() {
        if (this.validateSubmitAndApprove()) {
            this.approvalHeader = 'Approve Expenses';
            this.approvalButtonLabel = 'Approve';
            this.approveRecord = true;
            this.doSave();
        } else {
            this.showToast('Error', 'Please select Expenses to Approve', 'error');
        }
    }
    saveAndReject() {
        if (this.validateSubmitAndApprove()) {
            this.approvalHeader = 'Reject Expenses';
            this.approvalButtonLabel = 'Reject';
            this.rejectRecord = true;
            this.doSave();
        } else {
            this.showToast('Error', 'Please select Expenses to Reject', 'error');
        }
    }
    validateSubmitAndApprove() {
        this.submitforApproval = false;
        this.approveRecord = false;
        this.rejectRecord = false;
        const hasSelection = this.days.some(day =>
            day.lineItems.some(item => item.isSelected)
        );
        return hasSelection; // return boolean for validation
    }

    closeApprovalPopup() {
        this.isShowApprovalPopUp = false;
        this.submitforApproval = false;
        this.approveRecord = false;
        this.rejectRecord = false;
        this.showBody = true;
        this.approvalComments = '';
    }

    /**=====Hepler Methods============**/
    checkIsTA(existingItem) {
        return existingItem.Expense_Type__c == 'TA';
    }
    checkIsDA(existingItem) {
        return existingItem.Expense_Type__c == 'DA';
    }
    checkIsTransportCarBike(existingItem) {

        return existingItem.Travel_Mode__c == 'Car' || existingItem.Travel_Mode__c == 'Bike';
    }
    checkIsNewTransportCarBike(dayData) {

        return dayData.Mode_of_Transport__c == 'Car' || dayData.Mode_of_Transport__c == 'Bike';
    }
    checkIsTransportNotBikeCar(existingItem) {

        return existingItem.Expense_Type__c == 'TA' && existingItem.Travel_Mode__c != 'Car' && existingItem.Travel_Mode__c != 'Bike';
    }
    checkIsNewTransportNotBikeCar(existingItem) {
        return existingItem.Mode_of_Transport__c != 'Car' && existingItem.Mode_of_Transport__c != 'Bike';
    }
    checkIsLodging(existingItem) {
        return existingItem.Expense_Type__c == 'Accommodation';
    }
    checkIsLocalConveyance(existingItem) {
        return existingItem.Expense_Type__c == 'Local Conveyance';
    }
    checkIsOtherExpense(existingItem) {
        return existingItem.Expense_Type__c == 'Other/MISC' ||
            existingItem.Expense_Type__c == 'Courier Charges' || existingItem.Expense_Type__c == 'Food' ||
            existingItem.Expense_Type__c == 'Food Allowance' ||
            existingItem.Expense_Type__c == 'Transport Conveyance' ||
            existingItem.Expense_Type__c == 'Printing Charges' ||
            existingItem.Expense_Type__c == 'Stationary Charges';
    }
    checkIstransportExpense(existingItem) {
        return existingItem.Expense_Type__c == 'Transport Conveyance';
    }
    checkIsRemarksMandatory(existingItem) {
        let retnval = false;
        if (this.eligibilities.Mandatory_Remarks_File_Types__c &&
            this.eligibilities.Mandatory_Remarks_File_Types__c.split(';').includes(existingItem.Expense_Type__c)
        ) {
            retnval = true;
        }
        return retnval;
    }
    checkIsfileMandatory(existingItem) {
        let retnval = false;
        if (this.eligibilities.Mandatory_File_Expense_Types__c &&
            this.eligibilities.Mandatory_File_Expense_Types__c.split(';').includes(existingItem.Expense_Type__c)
        ) {
            retnval = true;
        }
        return retnval;
    }
    checkisShowFood(existingItem) {
        return existingItem.Expense_Type__c == 'DA' && existingItem.Travel_Type__c === 'Field - Other State';
    }
    checkisLodgingFoodExpense(existingItem) {
        return existingItem.Expense_Type__c == 'Lodging + Food';
    }
    getApprovalStatusClass(existingItem) {
        let retunval = 'legend-colorBlock notsubmitted-exp';
        if (existingItem.Approval_Status__c == 'Pending') { retunval = 'legend-colorBlock submitted-exp'; }
        else if (existingItem.Approval_Status__c == 'Level 1 Approved' || existingItem.Approval_Status__c == 'HR Approved' || existingItem.Approval_Status__c == 'Level 2 Approved') { retunval = 'legend-colorBlock approved-exp'; }
        else if (existingItem.Approval_Status__c == 'Level 1 Rejected' || existingItem.Approval_Status__c == 'HR Rejected' || existingItem.Approval_Status__c == 'Level 2 Rejected') { retunval = 'legend-colorBlock rejected-exp'; }
        return retunval;
    }
    checkIsMobileExpense(existingItem) {
        return existingItem.Expense_Type__c == 'Mobile Charges';
    }
    getItemClass(item) {
        let retnval = false;
        if (this.eligibilities.Mandatory_Remarks_File_Types__c &&
            this.eligibilities.Mandatory_Remarks_File_Types__c.split(';').includes(item.Expense_Type__c)
        ) {
            retnval = true;
        }
        if (item.Expense_Type__c === 'TA') {
            let customDesktopClass = 'slds-size_1-of-4 slds-p-horizontal_small';
            if (retnval && this.showLimitFields) {
                customDesktopClass = 'slds-size_1-of-6 slds-p-horizontal_small';
            }
            else if ((retnval && !this.showLimitFields) || (!retnval && this.showLimitFields)) {
                customDesktopClass = 'slds-size_1-of-5 slds-p-horizontal_small';
            }
            else {
                customDesktopClass = 'slds-size_1-of-4 slds-p-horizontal_small';
            }

            let customClass = this.isDesktop ? customDesktopClass : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'DA') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Lodging') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-4 slds-p-horizontal_small' : 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Local Conveyance') {

            let customDesktopClass = 'slds-size_1-of-3 slds-p-horizontal_small';
            if (retnval && this.showLimitFields) {
                customDesktopClass = 'slds-size_1-of-4 slds-p-horizontal_small';
            }
            else if ((retnval && !this.showLimitFields) || (!retnval && this.showLimitFields)) {
                customDesktopClass = 'slds-size_1-of-3 slds-p-horizontal_small';
            }
            else {
                customDesktopClass = 'slds-size_1-of-2 slds-p-horizontal_small';
            }

            let customClass = this.isDesktop ? customDesktopClass : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Other/MISC') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Courier Charges') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Mobile Charges') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Food') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else if (item.Expense_Type__c === 'Transport Conveyance') {
            let customClass = this.isDesktop ? retnval ? 'slds-size_1-of-4 slds-p-horizontal_small' : 'slds-size_1-of-3 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
        else {
            let customClass = this.isDesktop ? 'slds-size_1-of-2 slds-p-horizontal_small' : 'slds-size_1-of-2 slds-p-horizontal_small';
            return customClass;
        }
    }

    disableDayWiseCheckBox() {
        this.days = this.days.map(dayData => {
            // Check if all items under this day are disabled
            const allDisabled = dayData.lineItems.every(item => item.isCheckboxDisabled === true);

            return {
                ...dayData,
                isCheckBoxDisabled: allDisabled,
                dayheaderClass: allDisabled ? 'blueColor day-header slds-grid slds-grid_align-spread slds-p-around_small' : 'colorIdentification day-header slds-grid slds-grid_align-spread slds-p-around_small',
            };
        });
    }


    get toggleIconName() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }

    get toggleIconAltText() {
        return this.isExpanded ? 'Collapse section' : 'Expand section';
    }

    handleToggle() {
        this.isExpanded = !this.isExpanded;
    }
    get sectionClass() {
        return this.isExpanded ? 'slds-accordion__section slds-is-open' : 'slds-accordion__content slds-hide';
    }

    /**==============Disabled values========= **/
    disableDaAmount(existingItem) {
        let OwnerId = this.expense.OwnerId;
        let loggedInUserId = this.loggedInUser.Id;
        let exp = this.expense;
        let retunval = true;
        if (loggedInUserId == OwnerId) {
            retunval = true;
        }
        // Case 1: Level 1 Approver
        else if (exp.Expense_Approver_L1__c != null && exp.Expense_Approver_L1__c == loggedInUserId && existingItem.Approval_Status__c == 'Pending') {
            retunval = false;
        }


        return retunval;
    }
    disableExpenseType(existingItem) {
        if (existingItem.Expense_Type__c === 'TA' || existingItem.Expense_Type__c === 'DA') {
            return true;
        }
        else {
            let retunVal = true;
            let OwnerId = this.expense.OwnerId;
            let loggedInUserId = this.loggedInUser.Id;
            let exp = this.expense;
            if (loggedInUserId == OwnerId) {
                if (existingItem.Approval_Status__c != 'Pending' && existingItem.Approval_Status__c !== 'Level 1 Approved' &&
                    existingItem.Approval_Status__c !== 'Level 2 Approved' &&
                    existingItem.Approval_Status__c !== 'HR Approved') {
                    retunVal = false;
                }
            }
            // Case 1: Level 1 Approver
            else if (exp.Expense_Approver_L1__c != null && exp.Expense_Approver_L1__c == loggedInUserId && existingItem.Approval_Status__c == 'Pending') {
                retunVal = false;
            }


            return retunVal;
        }
    }
    isShowDeleteButton(existingItem) {
        let OwnerId = this.expense.OwnerId;
        let loggedInUserId = this.loggedInUser.Id;
        let exp = this.expense;
        let retunVal = false;
        if (existingItem.Expense_Type__c == 'DA') {
            retunVal = false;
        }
        else if (loggedInUserId == OwnerId) {
            if (existingItem.Approval_Status__c != 'Pending' && existingItem.Approval_Status__c !== 'Level 1 Approved' &&
                existingItem.Approval_Status__c !== 'Level 2 Approved' &&
                existingItem.Approval_Status__c !== 'HR Approved' && existingItem.Approval_Status__c !== 'Approved') {
                retunVal = true;
            }
        }
        // Case 1: Level 1 Approver
        else if (exp.Expense_Approver_L1__c != null && exp.Expense_Approver_L1__c == loggedInUserId && existingItem.Approval_Status__c == 'Pending') {
            retunVal = true;
        }


        return retunVal;
    }
    getCheckBoxDisabled(existingItem) {
        let exp = this.expense;
        let retunVal = true;
        let OwnerId = this.expense.OwnerId;
        let loggedInUserId = this.loggedInUser.Id;
        if (loggedInUserId == OwnerId) {
            if (existingItem.Approval_Status__c != 'Pending' && existingItem.Approval_Status__c !== 'Level 1 Approved' &&
                existingItem.Approval_Status__c !== 'Level 2 Approved' &&
                existingItem.Approval_Status__c !== 'HR Approved') {
                retunVal = false;
            }
        }
        else {
            // Case 1: Level 1 Approver
            if (exp.Expense_Approver_L1__c != null && exp.Expense_Approver_L1__c == loggedInUserId && existingItem.Approval_Status__c == 'Pending') {
                retunVal = false;
            }

        }
        return retunVal;

    }

    /**============Picklist Values==========**/
    getPicklistValueFromList(optionsArray) {
        return optionsArray.map(option => ({ label: option, value: option }));
    }
    getFilteredPicklistValueList(optionsArray) {
        // Filter out 'Draft' and map to label-value pairs
        let filteredOptions = optionsArray
            .filter(option => option !== 'Draft')
            .map(option => ({ label: option, value: option }));

        // Add 'All' at the beginning
        return [{ label: 'All', value: 'All' }, ...filteredOptions];
    }

    getTravelModePicklistValues(existingItem) {
        let travelModes = [];
        if (existingItem.Travel_Type__c == 'Field - Other State' || existingItem.Travel_Type__c == 'Field - Other District') {
            //Getting up contry travel types
            let selectedModes = this.eligibilities.Travel_Mode_UC__c
                ? this.eligibilities.Travel_Mode_UC__c.split(';')
                : [];

            // Filter from allTravelModes where value matches
            travelModes = this.travelModes.filter(mode =>
                selectedModes.includes(mode.value)
            );

        }
        else if (existingItem.Travel_Type__c == 'In Office' || existingItem.Travel_Type__c == 'Field - Home District') {
            //Getting up contry travel types
            let selectedModes = this.eligibilities.Travel_Mode_HQ__c
                ? this.eligibilities.Travel_Mode_HQ__c.split(';')
                : [];

            // Filter from allTravelModes where value matches
            travelModes = this.travelModes.filter(mode =>
                selectedModes.includes(mode.value)
            );

        }
        // Add "Select option" at the beginning
        travelModes = [{ label: 'Select option', value: '' }, ...travelModes];
        return travelModes;
    }
    getExpenseTypePicklistValues(existingItem) {
        let expenseTypes = []
        if (existingItem.Travel_Type__c == 'Field - Other State' || existingItem.Travel_Type__c == 'Field - Other District') {
            //Getting up contry Expense types
            let selectedexpenseTypes = this.eligibilities.Expense_Type_UC__c
                ? this.eligibilities.Expense_Type_UC__c.split(';')
                : [];
            // Filter from allTravelModes where value matches
            expenseTypes = this.expenseTypes.filter(mode =>
                selectedexpenseTypes.includes(mode.value)
            );
        }
        else if (existingItem.Travel_Type__c == 'In Office' || existingItem.Travel_Type__c == 'Field - Home District') {
            //Getting up contry Expense types
            let selectedexpenseTypes = this.eligibilities.Expense_Type_HQ__c
                ? this.eligibilities.Expense_Type_HQ__c.split(';')
                : [];

            // Filter from allTravelModes where value matches
            expenseTypes = this.expenseTypes.filter(mode =>
                selectedexpenseTypes.includes(mode.value)
            );

        }
        // Add "Select option" at the beginning
        expenseTypes = [{ label: 'Select option', value: '' }, ...expenseTypes];
        return expenseTypes;
    }

    parseCommentHistory(updatedComments) {
        if (!updatedComments || updatedComments.trim() === '') {
            return [];
        }

        // Split on double newlines (each comment block is separated by '\n\n')
        const commentBlocks = updatedComments.split(/\n\s*\n/);

        const parsedList = commentBlocks
            .map(block => {
                const match = block.match(/^\[(.*?)\]\s*([\s\S]*)$/);
                if (match) {
                    const meta = `[${match[1].trim()}]`;
                    const text = match[2].trim();

                    // Extract date-time portion (before '|')
                    const datePart = match[1].split('|')[0].trim();

                    // Try to parse it into a Date object
                    const parsedDate = new Date(Date.parse(datePart.replace(/-/g, ' ')));

                    return {
                        meta,
                        text,
                        date: isNaN(parsedDate) ? null : parsedDate
                    };
                }
                return null;
            })
            .filter(entry => entry !== null);

        // Sort descending (latest first)
        parsedList.sort((a, b) => {
            if (!a.date) return 1;
            if (!b.date) return -1;
            return b.date - a.date;
        });

        return parsedList;
    }
    filterExpenseItems() {

    }




    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
    generateUUID() {
        const ownerId = this.OwnerId ? this.OwnerId : 'anon';
        let uid;
        if (window.crypto && crypto.randomUUID) {
            uid = crypto.randomUUID();
        } else {
            uid = Date.now().toString(36) + Math.random().toString(36).substring(2, 15);
        }
        return `${ownerId}-${uid}`;
    }
    showFieldError(fieldPrefix) {
        const inputFields = this.template.querySelectorAll(`[data-id^="${fieldPrefix}"]`);
        if (inputFields.length > 0) {
            inputFields.forEach(input => {
                input.reportValidity(); // Show validation error
            });
        }
    }
    dispatchToAura(textMessage, expenseId) {
        // Created a custom event to Pass to aura component
        const event = new CustomEvent('closepopup', {
            detail: {
                eventType: textMessage,
                Id: expenseId,
            },
        });
        this.dispatchEvent(event);
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
}