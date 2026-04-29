import { LightningElement, api, wire, track } from 'lwc';
import getVisitLocations from '@salesforce/apex/DailyLogVisitMapController.getVisitLocations';
import getVisitLocationsByUserAndDate from '@salesforce/apex/DailyLogVisitMapController.getVisitLocationsByUserAndDate';
import GOOGLE_MAPS_API_KEY from '@salesforce/label/c.GOOGLE_MAPS_API_KEY';

const GMAPS_LOAD_FLAG = '__cyrixGmapsLoading';
const GMAPS_CALLBACK = '__cyrixGmapsLoaded';

export default class DailyLogVisitMap extends LightningElement {
    @api recordId;

    @track visitList = [];
    @track isLoading = false;
    @track error;
    @track hasLocations = false;
    @track showNoData = false;
    @track selectedUserId = '';
    @track selectedDate = '';

    mapInstance;
    mapMarkers = [];
    mapPolyline;
    pendingRender = false;

    get isSearchDisabled() {
        return !this.selectedUserId || !this.selectedDate;
    }

    get visitCount() {
        return this.visitList ? this.visitList.length : 0;
    }

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

    renderedCallback() {
        if (this.pendingRender && this.hasLocations) {
            this.pendingRender = false;
            this.ensureMapsLoaded()
                .then(() => this.drawMap())
                .catch(err => {
                    console.error('Google Maps load failed', err);
                    this.error = 'Unable to load Google Maps. Check API key / CSP setup.';
                });
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
                this.visitList = data.map(v => ({
                    ...v,
                    showCompany: v.isLead && !!v.companyName
                }));
                this.hasLocations = true;
                this.showNoData = false;
                this.pendingRender = true;
            } else {
                this.visitList = [];
                this.hasLocations = false;
                this.showNoData = true;
            }
            this.error = undefined;
        } else if (error) {
            this.error = error.body ? error.body.message : 'Error loading visit locations';
            this.visitList = [];
            this.hasLocations = false;
            this.showNoData = false;
        }
    }

    // ===== Google Maps loader =====
    ensureMapsLoaded() {
        if (window.google && window.google.maps) {
            return Promise.resolve();
        }
        if (window[GMAPS_LOAD_FLAG]) {
            return window[GMAPS_LOAD_FLAG];
        }
        window[GMAPS_LOAD_FLAG] = new Promise((resolve, reject) => {
            window[GMAPS_CALLBACK] = () => resolve();
            const script = document.createElement('script');
            script.src =
                `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}` +
                `&libraries=geometry&callback=${GMAPS_CALLBACK}`;
            script.async = true;
            script.defer = true;
            script.onerror = reject;
            document.head.appendChild(script);
        });
        return window[GMAPS_LOAD_FLAG];
    }

    // ===== Render markers + polyline =====
    drawMap() {
        const container = this.template.querySelector('.custom-map');
        if (!container) return;
        if (!this.visitList || this.visitList.length === 0) return;

        const points = this.visitList.map(v => ({
            lat: parseFloat(v.latitude),
            lng: parseFloat(v.longitude)
        }));

        // Init or reuse the map
        if (!this.mapInstance) {
            this.mapInstance = new window.google.maps.Map(container, {
                center: points[0],
                zoom: 14,
                streetViewControl: false,
                mapTypeControl: false,
                fullscreenControl: true
            });
        } else {
            this.mapInstance.setCenter(points[0]);
        }

        // Clear previous markers / polyline
        this.mapMarkers.forEach(m => m.setMap(null));
        this.mapMarkers = [];
        if (this.mapPolyline) {
            this.mapPolyline.setMap(null);
            this.mapPolyline = null;
        }

        // Add a numbered marker per visit, in chronological order
        const bounds = new window.google.maps.LatLngBounds();
        this.visitList.forEach((v, idx) => {
            const position = points[idx];
            const marker = new window.google.maps.Marker({
                position,
                map: this.mapInstance,
                label: {
                    text: String(idx + 1),
                    color: '#ffffff',
                    fontWeight: '600',
                    fontSize: '12px'
                },
                title: v.customerName
            });
            const info = new window.google.maps.InfoWindow({
                content:
                    `<div style="font-size:12px;line-height:1.4">` +
                    `<strong>${idx + 1}. ${this.escape(v.customerName)}</strong><br/>` +
                    (v.companyName ? `🏢 ${this.escape(v.companyName)}<br/>` : '') +
                    `🕒 ${this.escape(v.checkInTime)}` +
                    (v.checkOutTime ? ` → ${this.escape(v.checkOutTime)}` : '') +
                    `</div>`
            });
            marker.addListener('click', () => info.open(this.mapInstance, marker));
            this.mapMarkers.push(marker);
            bounds.extend(position);
        });

        // Polyline that connects pins in check-in order
        if (points.length >= 2) {
            this.mapPolyline = new window.google.maps.Polyline({
                path: points,
                geodesic: true,
                strokeColor: '#0a5b8c',
                strokeOpacity: 0.9,
                strokeWeight: 4,
                icons: [{
                    icon: {
                        path: window.google.maps.SymbolPath.FORWARD_CLOSED_ARROW,
                        scale: 3,
                        strokeColor: '#0a5b8c'
                    },
                    offset: '50%',
                    repeat: '120px'
                }]
            });
            this.mapPolyline.setMap(this.mapInstance);
        }

        // Fit map to all stops (with padding)
        if (points.length > 1) {
            this.mapInstance.fitBounds(bounds, 60);
        } else {
            this.mapInstance.setZoom(15);
        }
    }

    escape(str) {
        if (str == null) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    }
}
