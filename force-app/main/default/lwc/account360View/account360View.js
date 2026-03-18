import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAccount360Data from '@salesforce/apex/Account360Controller.getAccount360Data';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';

export default class Account360View extends NavigationMixin(LightningElement) {

    @api recordId;

    googleIcons = {
        account: GOOGLE_ICONS + '/googleIcons/apartment.png',
        overallSummery: GOOGLE_ICONS + '/googleIcons/overallSummery.png',
        visit: GOOGLE_ICONS + '/googleIcons/visit.png',
        expense: GOOGLE_ICONS + '/googleIcons/expense.png',
        Productivity: GOOGLE_ICONS + '/googleIcons/Productivity.png'
    };

    @track accountData;
    @track visits = [];
    @track orders = [];
    @track contacts = [];
    @track openTasks = [];

    // Metrics
    totalVisits = 0;
    completedVisits = 0;
    inProgressVisits = 0;
    plannedVisits = 0;
    missedVisits = 0;
    totalOrders = 0;
    totalOrderAmount = 0;
    attachmentCount = 0;

    // Section toggles
    @track isSectionDetailsOpen = true;
    @track isSectionMetricsOpen = true;
    @track isSectionVisitsOpen = false;
    @track isSectionOrdersOpen = false;
    @track isSectionContactsOpen = false;
    @track isSectionTasksOpen = false;

    isPageLoaded = true;
    hasError = false;
    errorMessage = '';

    visitColumns = [
        { label: 'Visit', fieldName: 'Name', type: 'text' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' },
        { label: 'Visit Date', fieldName: 'formattedVisitDate', type: 'text' },
        { label: 'Type', fieldName: 'Visit_Type__c', type: 'text' },
        { label: 'Owner', fieldName: 'ownerName', type: 'text' }
    ];

    orderColumns = [
        { label: 'Order Number', fieldName: 'OrderNumber', type: 'text' },
        { label: 'Amount', fieldName: 'TotalAmount', type: 'currency' },
        { label: 'Status', fieldName: 'Status', type: 'text' },
        { label: 'Date', fieldName: 'formattedDate', type: 'text' }
    ];

    contactColumns = [
        { label: 'Name', fieldName: 'Name', type: 'text' },
        { label: 'Title', fieldName: 'Title', type: 'text' },
        { label: 'Email', fieldName: 'Email', type: 'email' },
        { label: 'Phone', fieldName: 'Phone', type: 'phone' }
    ];

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        this.isPageLoaded = true;
        getAccount360Data({ accountId: this.recordId })
            .then(result => {
                this.accountData = result.account;

                // Process visits
                this.visits = result.visits.map(v => ({
                    ...v,
                    formattedVisitDate: v.Visit_Date__c
                        ? new Date(v.Visit_Date__c).toLocaleDateString('en-IN')
                        : '',
                    ownerName: v.Owner ? v.Owner.Name : ''
                }));

                // Process orders
                this.orders = result.orders.map(o => ({
                    ...o,
                    formattedDate: o.CreatedDate
                        ? new Date(o.CreatedDate).toLocaleDateString('en-IN')
                        : ''
                }));

                this.contacts = result.contacts;
                this.openTasks = result.openTasks;

                // Metrics
                this.totalVisits = result.totalVisits;
                this.completedVisits = result.completedVisits;
                this.inProgressVisits = result.inProgressVisits;
                this.plannedVisits = result.plannedVisits;
                this.missedVisits = result.missedVisits;
                this.totalOrders = result.totalOrders;
                this.totalOrderAmount = result.totalOrderAmount || 0;
                this.attachmentCount = result.attachmentCount;

                this.isPageLoaded = false;
            })
            .catch(error => {
                this.hasError = true;
                this.errorMessage = error.body ? error.body.message : 'An error occurred loading account data.';
                this.isPageLoaded = false;
                console.error('Account360 error:', error);
            });
    }

    // Computed properties
    get accountName() {
        return this.accountData ? this.accountData.Name : '';
    }
    get accountPhone() {
        return this.accountData ? this.accountData.Phone : '--';
    }
    get accountCode() {
        return this.accountData ? this.accountData.Customer_Code__c : '--';
    }
    get accountType() {
        return this.accountData ? this.accountData.Customer_Type__c : '--';
    }
    get accountStatus() {
        return this.accountData ? this.accountData.Status__c : '--';
    }
    get accountCity() {
        return this.accountData ? this.accountData.City__c : '--';
    }
    get accountState() {
        return this.accountData ? this.accountData.State__c : '--';
    }
    get accountPreference() {
        return this.accountData ? this.accountData.Customer_Preference__c : '--';
    }
    get accountIndustry() {
        return this.accountData ? this.accountData.Industry : '--';
    }
    get accountWebsite() {
        return this.accountData ? this.accountData.Website : '--';
    }
    get formattedTotalOrderAmount() {
        return this.totalOrderAmount.toLocaleString('en-IN', {
            style: 'currency',
            currency: 'INR',
            minimumFractionDigits: 2
        });
    }
    get completionRate() {
        if (this.totalVisits === 0) return '0%';
        return Math.round((this.completedVisits / this.totalVisits) * 100) + '%';
    }
    get hasVisits() {
        return this.visits.length > 0;
    }
    get hasOrders() {
        return this.orders.length > 0;
    }
    get hasContacts() {
        return this.contacts.length > 0;
    }
    get hasTasks() {
        return this.openTasks.length > 0;
    }

    // Chevron icons
    get detailsChevron() {
        return this.isSectionDetailsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }
    get metricsChevron() {
        return this.isSectionMetricsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }
    get visitsChevron() {
        return this.isSectionVisitsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }
    get ordersChevron() {
        return this.isSectionOrdersOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }
    get contactsChevron() {
        return this.isSectionContactsOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }
    get tasksChevron() {
        return this.isSectionTasksOpen ? 'utility:chevronup' : 'utility:chevrondown';
    }

    // Toggle section handlers
    toggleDetails() {
        this.isSectionDetailsOpen = !this.isSectionDetailsOpen;
    }
    toggleMetrics() {
        this.isSectionMetricsOpen = !this.isSectionMetricsOpen;
    }
    toggleVisits() {
        this.isSectionVisitsOpen = !this.isSectionVisitsOpen;
    }
    toggleOrders() {
        this.isSectionOrdersOpen = !this.isSectionOrdersOpen;
    }
    toggleContacts() {
        this.isSectionContactsOpen = !this.isSectionContactsOpen;
    }
    toggleTasks() {
        this.isSectionTasksOpen = !this.isSectionTasksOpen;
    }

    navigateToVisit(event) {
        const visitId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: visitId,
                objectApiName: 'Visit__c',
                actionName: 'view'
            }
        });
    }

    navigateToOrder(event) {
        const orderId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    navigateToContact(event) {
        const contactId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: contactId,
                objectApiName: 'Contact',
                actionName: 'view'
            }
        });
    }

    handleRefresh() {
        this.loadData();
    }
}
