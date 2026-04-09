import { LightningElement, api, wire, track } from 'lwc';
import getVisitLocations from '@salesforce/apex/DailyLogVisitMapController.getVisitLocations';

export default class DailyLogVisitMap extends LightningElement {
    @api recordId;

    @track mapMarkers = [];
    @track isLoading = true;
    @track error;
    @track hasLocations = false;
    @track showNoData = false;

    @wire(getVisitLocations, { dailyLogId: '$recordId' })
    wiredVisitLocations({ data, error }) {
        this.isLoading = false;
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
                this.hasLocations = true;
                this.showNoData = false;
            } else {
                this.mapMarkers = [];
                this.hasLocations = false;
                this.showNoData = true;
            }
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Error loading visit locations';
            this.mapMarkers = [];
            this.hasLocations = false;
            this.showNoData = false;
        }
    }
}
