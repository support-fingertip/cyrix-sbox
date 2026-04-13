import { LightningElement, api, wire, track } from 'lwc';
import getVisitLocations from '@salesforce/apex/DailyLogVisitMapController.getVisitLocations';
import getVisitLocationsByUserAndDate from '@salesforce/apex/DailyLogVisitMapController.getVisitLocationsByUserAndDate';

export default class DailyLogVisitMap extends LightningElement {
    @api recordId;

    @track mapMarkers = [];
    @track visitList = [];
    @track isLoading = false;
    @track error;
    @track hasLocations = false;
    @track showNoData = false;
    @track selectedUserId = '';
    @track selectedDate = '';
    @track zoomLevel = 12;
    @track mapCenter;

    get isSearchDisabled() {
        return !this.selectedUserId || !this.selectedDate;
    }

    get visitCount() {
        return this.visitList ? this.visitList.length : 0;
    }

    // Record Page mode - auto load using recordId
    @wire(getVisitLocations, { dailyLogId: '$recordId' })
    wiredVisitLocations({ data, error }) {
        if (!this.recordId) return;
        this.isLoading = false;
        this.processResults(data, error);
    }

    connectedCallback() {
        if (this.recordId) {
            this.isLoading = true;
        }
    }

    handleUserChange(event) {
        this.selectedUserId = event.detail.recordId;
    }

    handleDateChange(event) {
        this.selectedDate = event.target.value;
    }

    handleShowRoute() {
        if (!this.selectedUserId || !this.selectedDate) {
            return;
        }
        this.isLoading = true;
        this.error = undefined;
        this.hasLocations = false;
        this.showNoData = false;

        getVisitLocationsByUserAndDate({
            userId: this.selectedUserId,
            visitDate: this.selectedDate
        })
            .then(data => {
                this.isLoading = false;
                this.processResults(data, null);
            })
            .catch(error => {
                this.isLoading = false;
                this.processResults(null, error);
            });
    }

    processResults(data, error) {
        if (data) {
            if (data.length > 0) {
                this.mapMarkers = data.map(v => ({
                    location: {
                        Latitude: v.latitude,
                        Longitude: v.longitude
                    },
                    title: v.title,
                    description: v.description,
                    icon: v.icon
                }));

                this.visitList = data;

                // Set map center to first visit
                this.mapCenter = {
                    location: {
                        Latitude: data[0].latitude,
                        Longitude: data[0].longitude
                    }
                };

                this.hasLocations = true;
                this.showNoData = false;
            } else {
                this.mapMarkers = [];
                this.visitList = [];
                this.hasLocations = false;
                this.showNoData = true;
            }
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Error loading visit locations';
            this.mapMarkers = [];
            this.visitList = [];
            this.hasLocations = false;
            this.showNoData = false;
        }
    }
}