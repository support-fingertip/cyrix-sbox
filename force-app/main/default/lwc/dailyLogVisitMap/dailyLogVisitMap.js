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

                this.visitList = data.map(v => ({
                    ...v,
                    showCompany: v.isLead && !!v.companyName
                }));

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

    // Build a Google Maps Directions URL that strings the visits together
    // in chronological order (origin = first visit, destination = last,
    // any intermediate visits become waypoints). This effectively
    // "connects" the location pins along the rep's actual check-in order.
    get googleRouteUrl() {
        if (!this.visitList || this.visitList.length === 0) return '';
        const points = this.visitList.map(v => `${v.latitude},${v.longitude}`);
        if (points.length === 1) {
            return `https://www.google.com/maps/search/?api=1&query=${points[0]}`;
        }
        const origin = points[0];
        const destination = points[points.length - 1];
        const waypoints = points.slice(1, -1).join('|');
        let url = `https://www.google.com/maps/dir/?api=1&travelmode=driving`
            + `&origin=${encodeURIComponent(origin)}`
            + `&destination=${encodeURIComponent(destination)}`;
        if (waypoints) {
            url += `&waypoints=${encodeURIComponent(waypoints)}`;
        }
        return url;
    }

    get hasRoutableStops() {
        return this.visitList && this.visitList.length >= 2;
    }

    handleOpenRoute() {
        const url = this.googleRouteUrl;
        if (url) {
            window.open(url, '_blank');
        }
    }
}