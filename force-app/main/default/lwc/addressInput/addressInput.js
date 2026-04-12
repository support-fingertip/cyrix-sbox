import { LightningElement, api, track } from 'lwc';
import searchAddress from '@salesforce/apex/AddressSearchController.searchAddress';
import getPlaceDetails from '@salesforce/apex/AddressSearchController.getPlaceDetails';

export default class AddressInput extends LightningElement {
    @api label = 'Address';

    // Address values (set externally to pre-populate)
    @api
    get name() { return this._name; }
    set name(val) { this._name = val || ''; }

    @api
    get street() { return this._street; }
    set street(val) { this._street = val || ''; }

    @api
    get city() { return this._city; }
    set city(val) { this._city = val || ''; }

    @api
    get state() { return this._state; }
    set state(val) { this._state = val || ''; }

    @api
    get postalCode() { return this._postalCode; }
    set postalCode(val) { this._postalCode = val || ''; }

    @api
    get country() { return this._country; }
    set country(val) { this._country = val || 'IN'; }

    // Internal state
    _name = '';
    _street = '';
    _city = '';
    _state = '';
    _postalCode = '';
    _country = 'IN';

    searchValue = '';
    @track suggestions = [];
    showSuggestions = false;
    isSearching = false;
    _searchTimer;

    // Expose current values
    get nameValue() { return this._name; }
    get streetValue() { return this._street; }
    get cityValue() { return this._city; }
    get stateValue() { return this._state; }
    get postalCodeValue() { return this._postalCode; }
    get countryValue() { return this._country; }

    get searchLabel() { return this.label + ' - Search'; }
    get showStatePicklist() { return this._country === 'IN'; }

    // Public method to get all address values
    @api
    getAddress() {
        return {
            name: this._name,
            street: this._street,
            city: this._city,
            state: this._state,
            postalCode: this._postalCode,
            country: this._country
        };
    }

    // Public method to set all address values at once
    @api
    setAddress(addr) {
        if (!addr) return;
        this._name = addr.name || '';
        this._street = addr.street || '';
        this._city = addr.city || '';
        this._state = addr.state || '';
        this._postalCode = addr.postalCode || '';
        this._country = addr.country || 'IN';
    }

    // ===== SEARCH HANDLERS =====

    handleSearchInput(event) {
        const val = event.target.value;
        this.searchValue = val;

        if (this._searchTimer) {
            clearTimeout(this._searchTimer);
        }

        if (!val || val.length < 3) {
            this.suggestions = [];
            this.showSuggestions = false;
            return;
        }

        this._searchTimer = setTimeout(() => {
            this.doSearch(val);
        }, 350);
    }

    async doSearch(input) {
        this.isSearching = true;
        try {
            const results = await searchAddress({ input });
            this.suggestions = results || [];
            this.showSuggestions = this.suggestions.length > 0;
        } catch (error) {
            console.error('Address search error:', error);
            this.suggestions = [];
            this.showSuggestions = false;
        } finally {
            this.isSearching = false;
        }
    }

    async handleSelectSuggestion(event) {
        const placeId = event.currentTarget.dataset.placeId;
        this.showSuggestions = false;
        this.suggestions = [];
        this.searchValue = '';
        this.isSearching = true;

        try {
            const detail = await getPlaceDetails({ placeId });
            if (detail) {
                this._street = detail.street || '';
                this._city = detail.city || '';
                this._postalCode = detail.postalCode || '';

                if (detail.country) {
                    this._country = detail.country;
                }
                if (detail.state) {
                    this._state = detail.state;
                }

                this.fireAddressChange();
            }
        } catch (error) {
            console.error('Place details error:', error);
        } finally {
            this.isSearching = false;
        }
    }

    // ===== FIELD CHANGE HANDLER =====

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.detail ? event.detail.value : event.target.value;

        switch (field) {
            case 'name':
                this._name = value || '';
                break;
            case 'street':
                this._street = value || '';
                break;
            case 'city':
                this._city = value || '';
                break;
            case 'state':
                this._state = value || '';
                break;
            case 'postalCode':
                this._postalCode = value || '';
                break;
            case 'country':
                this._country = value || '';
                // Reset state when country changes
                if (value !== 'IN') {
                    this._state = '';
                }
                break;
            default:
                break;
        }

        this.fireAddressChange();
    }

    fireAddressChange() {
        this.dispatchEvent(new CustomEvent('addresschange', {
            detail: this.getAddress()
        }));
    }

    // ===== PICKLIST OPTIONS =====

    get countryOptions() {
        return [
            { label: 'India', value: 'IN' },
            { label: 'United States', value: 'US' },
            { label: 'United Kingdom', value: 'GB' },
            { label: 'United Arab Emirates', value: 'AE' },
            { label: 'Singapore', value: 'SG' },
            { label: 'Australia', value: 'AU' },
            { label: 'Canada', value: 'CA' },
            { label: 'Germany', value: 'DE' },
            { label: 'France', value: 'FR' },
            { label: 'Japan', value: 'JP' },
            { label: 'China', value: 'CN' },
            { label: 'South Korea', value: 'KR' },
            { label: 'Malaysia', value: 'MY' },
            { label: 'Thailand', value: 'TH' },
            { label: 'Indonesia', value: 'ID' },
            { label: 'Bangladesh', value: 'BD' },
            { label: 'Sri Lanka', value: 'LK' },
            { label: 'Nepal', value: 'NP' },
            { label: 'Saudi Arabia', value: 'SA' },
            { label: 'Qatar', value: 'QA' },
            { label: 'Kuwait', value: 'KW' },
            { label: 'Oman', value: 'OM' },
            { label: 'Bahrain', value: 'BH' },
            { label: 'South Africa', value: 'ZA' },
            { label: 'Nigeria', value: 'NG' },
            { label: 'Kenya', value: 'KE' },
            { label: 'Brazil', value: 'BR' },
            { label: 'Mexico', value: 'MX' },
            { label: 'Italy', value: 'IT' },
            { label: 'Spain', value: 'ES' },
            { label: 'Netherlands', value: 'NL' },
            { label: 'Sweden', value: 'SE' },
            { label: 'Switzerland', value: 'CH' },
            { label: 'New Zealand', value: 'NZ' }
        ];
    }

    get stateOptions() {
        return [
            { label: 'Andaman and Nicobar Islands', value: 'AN' },
            { label: 'Andhra Pradesh', value: 'AP' },
            { label: 'Arunachal Pradesh', value: 'AR' },
            { label: 'Assam', value: 'AS' },
            { label: 'Bihar', value: 'BR' },
            { label: 'Chandigarh', value: 'CH' },
            { label: 'Chhattisgarh', value: 'CT' },
            { label: 'Dadra and Nagar Haveli and Daman and Diu', value: 'DN' },
            { label: 'Delhi', value: 'DL' },
            { label: 'Goa', value: 'GA' },
            { label: 'Gujarat', value: 'GJ' },
            { label: 'Haryana', value: 'HR' },
            { label: 'Himachal Pradesh', value: 'HP' },
            { label: 'Jammu and Kashmir', value: 'JK' },
            { label: 'Jharkhand', value: 'JH' },
            { label: 'Karnataka', value: 'KA' },
            { label: 'Kerala', value: 'KL' },
            { label: 'Ladakh', value: 'LA' },
            { label: 'Lakshadweep', value: 'LD' },
            { label: 'Madhya Pradesh', value: 'MP' },
            { label: 'Maharashtra', value: 'MH' },
            { label: 'Manipur', value: 'MN' },
            { label: 'Meghalaya', value: 'ML' },
            { label: 'Mizoram', value: 'MZ' },
            { label: 'Nagaland', value: 'NL' },
            { label: 'Odisha', value: 'OD' },
            { label: 'Puducherry', value: 'PY' },
            { label: 'Punjab', value: 'PB' },
            { label: 'Rajasthan', value: 'RJ' },
            { label: 'Sikkim', value: 'SK' },
            { label: 'Tamil Nadu', value: 'TN' },
            { label: 'Telangana', value: 'TG' },
            { label: 'Tripura', value: 'TR' },
            { label: 'Uttar Pradesh', value: 'UP' },
            { label: 'Uttarakhand', value: 'UT' },
            { label: 'West Bengal', value: 'WB' }
        ];
    }
}
