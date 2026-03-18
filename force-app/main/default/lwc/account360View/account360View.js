import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAccountDetails from '@salesforce/apex/Account360ViewController.getAccountDetails';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';

export default class Account360View extends NavigationMixin(LightningElement) {

    @api recordId;
    @track accountData;
    @track isLoading = true;
    @track error;

    // Section toggle state
    dropdown = {
        summary: true,
        visits: true,
        orders: false,
        contacts: false
    };

    // Show all flags
    showAllVisits = false;
    showAllOrders = false;

    icons = {
        summery: GOOGLE_ICONS + '/googleIcons/summery.png',
        order: GOOGLE_ICONS + '/googleIcons/order.png'
    };

    connectedCallback() {
        this.loadAccountData();
    }

    loadAccountData() {
        this.isLoading = true;
        getAccountDetails({ accountId: this.recordId })
            .then(result => {
                this.accountData = result;
                this.error = undefined;
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error.body ? error.body.message : 'An error occurred while loading account data.';
                this.accountData = undefined;
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message: this.error,
                    variant: 'error'
                }));
            });
    }

    // Computed properties
    get hasVisits() {
        return this.accountData && this.accountData.recentVisits && this.accountData.recentVisits.length > 0;
    }

    get hasOrders() {
        return this.accountData && this.accountData.recentOrders && this.accountData.recentOrders.length > 0;
    }

    get hasContacts() {
        return this.accountData && this.accountData.contacts && this.accountData.contacts.length > 0;
    }

    get displayVisits() {
        if (!this.accountData) return [];
        return this.showAllVisits ? this.accountData.visits : this.accountData.recentVisits;
    }

    get displayOrders() {
        if (!this.accountData) return [];
        return this.showAllOrders ? this.accountData.orders : this.accountData.recentOrders;
    }

    get hasMoreVisits() {
        return this.accountData && this.accountData.visits && this.accountData.visits.length > 5;
    }

    get hasMoreOrders() {
        return this.accountData && this.accountData.orders && this.accountData.orders.length > 5;
    }

    get visitToggleLabel() {
        return this.showAllVisits ? 'Show Less' : 'View All Visits';
    }

    get orderToggleLabel() {
        return this.showAllOrders ? 'Show Less' : 'View All Orders';
    }

    get accountAddress() {
        if (!this.accountData || !this.accountData.account) return '';
        const acc = this.accountData.account;
        const parts = [acc.BillingStreet, acc.BillingCity, acc.BillingState, acc.BillingPostalCode, acc.BillingCountry].filter(Boolean);
        return parts.join(', ');
    }

    get hasAddress() {
        return this.accountAddress.length > 0;
    }

    // Visit status CSS classes
    getStatusClass(status) {
        switch (status) {
            case 'Completed': return 'status-badge status-completed';
            case 'In Progress': return 'status-badge status-inprogress';
            case 'Planned': return 'status-badge status-planned';
            case 'Missed': return 'status-badge status-missed';
            default: return 'status-badge';
        }
    }

    // Toggle sections
    toggleSummaryDropdown() {
        this.dropdown.summary = !this.dropdown.summary;
        this.toggleDropdownUI('.dropdown-body-summary', '.chevron-icon-summary', this.dropdown.summary);
    }

    toggleVisitsDropdown() {
        this.dropdown.visits = !this.dropdown.visits;
        this.toggleDropdownUI('.dropdown-body-visits', '.chevron-icon-visits', this.dropdown.visits);
    }

    toggleOrdersDropdown() {
        this.dropdown.orders = !this.dropdown.orders;
        this.toggleDropdownUI('.dropdown-body-orders', '.chevron-icon-orders', this.dropdown.orders);
    }

    toggleContactsDropdown() {
        this.dropdown.contacts = !this.dropdown.contacts;
        this.toggleDropdownUI('.dropdown-body-contacts', '.chevron-icon-contacts', this.dropdown.contacts);
    }

    toggleDropdownUI(bodySelector, chevronSelector, isOpen) {
        const dropdownBody = this.template.querySelector(bodySelector);
        const chevronIcon = this.template.querySelector(chevronSelector);
        if (dropdownBody) {
            if (isOpen) {
                dropdownBody.classList.add('active');
                if (chevronIcon) chevronIcon.iconName = 'utility:chevronup';
            } else {
                dropdownBody.classList.remove('active');
                if (chevronIcon) chevronIcon.iconName = 'utility:chevrondown';
            }
        }
    }

    // Toggle show all
    toggleAllVisits() {
        this.showAllVisits = !this.showAllVisits;
    }

    toggleAllOrders() {
        this.showAllOrders = !this.showAllOrders;
    }

    // Navigation
    navigateToRecord(event) {
        const recId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recId,
                actionName: 'view'
            }
        });
    }

    // Refresh data
    handleRefresh() {
        this.loadAccountData();
    }
}
