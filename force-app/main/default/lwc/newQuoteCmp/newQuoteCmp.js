import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getOpportunityContext from '@salesforce/apex/QuoteBuilderController.getOpportunityContext';
import searchProducts from '@salesforce/apex/QuoteBuilderController.searchProducts';
import saveQuoteWithLineItems from '@salesforce/apex/QuoteBuilderController.saveQuoteWithLineItems';

let rowCounter = 0;

export default class NewQuoteCmp extends NavigationMixin(LightningElement) {
    @api recordId; // Opportunity Id from record page

    // Loading & state
    isLoading = false;
    isSaving = false;

    // Opportunity context
    opportunityName = '';
    accountName = '';
    pricebookId;
    currencyCode = 'INR';

    // Quote header fields
    quoteName = '';
    quoteDate = '';
    validTillDays = '';
    validTillDate = '';
    vertical = '';
    shippingMode = '';
    billingAddress = '';
    shippingAddress = '';
    isActive = true;

    // Search
    searchTerm = '';
    categoryFilter = '';
    @track searchResults = [];
    showSearchResults = false;

    // Line items
    @track lineItems = [];

    // Additional charges
    shippingCharges = 0;
    transportCharges = 0;
    warrantyCost = 0;
    installationCost = 0;
    packingCharges = 0;
    trainingCost = 0;

    // ===== PICKLIST OPTIONS =====

    get validTillOptions() {
        return [
            { label: '15 Days', value: '15' },
            { label: '30 Days', value: '30' },
            { label: '45 Days', value: '45' },
            { label: '60 Days', value: '60' },
            { label: '90 Days', value: '90' }
        ];
    }

    get verticalOptions() {
        return [
            { label: 'Distribution/Sales', value: 'Distribution/Sales' },
            { label: 'Care 360 CMC', value: 'Care 360 CMC' },
            { label: 'QA/Calibration', value: 'QA/Calibration' },
            { label: 'Revive Lab', value: 'Revive Lab' },
            { label: 'Spares', value: 'Spares' },
            { label: 'Academy', value: 'Academy' },
            { label: 'Ciyan', value: 'Ciyan' },
            { label: 'Aurum', value: 'Aurum' },
            { label: 'Rental', value: 'Rental' },
            { label: 'Asset Management', value: 'Asset Management' }
        ];
    }

    get shippingModeOptions() {
        return [
            { label: '--None--', value: '' },
            { label: 'By Road', value: 'By Road' },
            { label: 'By Air', value: 'By Air' },
            { label: 'By Sea', value: 'By Sea' },
            { label: 'By Rail', value: 'By Rail' },
            { label: 'Courier', value: 'Courier' }
        ];
    }

    get taxTypeOptions() {
        return [
            { label: 'GST', value: 'GST' },
            { label: 'IGST', value: 'IGST' },
            { label: 'Exempt', value: 'Exempt' }
        ];
    }

    get categoryOptions() {
        return [
            { label: 'All Categories', value: '' },
            { label: 'Medical Equipment', value: 'Medical Equipment' },
            { label: 'Surgical Instruments', value: 'Surgical Instruments' },
            { label: 'Lab Equipment', value: 'Lab Equipment' },
            { label: 'Consumables', value: 'Consumables' },
            { label: 'Services', value: 'Services' },
            { label: 'Spares', value: 'Spares' }
        ];
    }

    // ===== COMPUTED PROPERTIES =====

    get hasLineItems() {
        return this.lineItems.length > 0;
    }

    get lineItemCount() {
        return this.lineItems.length;
    }

    get noSearchResults() {
        return this.showSearchResults && this.searchResults.length === 0;
    }

    get isSearchDisabled() {
        return !this.searchTerm || this.searchTerm.length < 2;
    }

    get isSaveDisabled() {
        return this.isSaving || this.lineItems.length === 0;
    }

    // ===== CALCULATIONS =====

    get subtotal() {
        return this.lineItems.reduce((sum, item) => {
            const base = (item.unitPrice || 0) * (item.quantity || 0);
            return sum + base;
        }, 0);
    }

    get totalDiscount() {
        return this.lineItems.reduce((sum, item) => {
            const base = (item.unitPrice || 0) * (item.quantity || 0);
            const discountAmt = base * ((item.discount || 0) / 100);
            return sum + discountAmt;
        }, 0);
    }

    get totalTax() {
        return this.lineItems.reduce((sum, item) => {
            if (item.taxType === 'Exempt') return sum;
            const base = (item.unitPrice || 0) * (item.quantity || 0);
            const afterDiscount = base - (base * ((item.discount || 0) / 100));
            const taxAmt = afterDiscount * ((item.taxPercent || 0) / 100);
            return sum + taxAmt;
        }, 0);
    }

    get totalCharges() {
        return (parseFloat(this.shippingCharges) || 0) +
               (parseFloat(this.transportCharges) || 0) +
               (parseFloat(this.warrantyCost) || 0) +
               (parseFloat(this.installationCost) || 0) +
               (parseFloat(this.packingCharges) || 0) +
               (parseFloat(this.trainingCost) || 0);
    }

    get grandTotal() {
        return this.subtotal - this.totalDiscount + this.totalTax + this.totalCharges;
    }

    // ===== WIRE: Load Opportunity Context =====

    @wire(getOpportunityContext, { opportunityId: '$recordId' })
    wiredContext({ error, data }) {
        if (data) {
            this.opportunityName = data.opportunityName;
            this.accountName = data.accountName;
            this.pricebookId = data.pricebookId;
            this.currencyCode = data.currencyCode || 'INR';
            this.vertical = data.vertical || '';
            this.billingAddress = data.billingAddress || '';
            this.shippingAddress = data.shippingAddress || '';
            this.quoteDate = new Date().toISOString().split('T')[0];
        } else if (error) {
            this.showError('Error loading opportunity', this.reduceErrors(error));
        }
    }

    // ===== HEADER HANDLERS =====

    handleQuoteNameChange(event) { this.quoteName = event.target.value; }
    handleQuoteDateChange(event) { this.quoteDate = event.target.value; this.calculateValidTillDate(); }
    handleVerticalChange(event) { this.vertical = event.detail.value; }
    handleShippingModeChange(event) { this.shippingMode = event.detail.value; }
    handleBillingAddressChange(event) { this.billingAddress = event.target.value; }
    handleShippingAddressChange(event) { this.shippingAddress = event.target.value; }
    handleIsActiveChange(event) { this.isActive = event.target.checked; }

    handleValidTillDaysChange(event) {
        this.validTillDays = event.detail.value;
        this.calculateValidTillDate();
    }

    calculateValidTillDate() {
        if (this.quoteDate && this.validTillDays) {
            const base = new Date(this.quoteDate);
            base.setDate(base.getDate() + parseInt(this.validTillDays, 10));
            this.validTillDate = base.toISOString().split('T')[0];
        }
    }

    // ===== SEARCH HANDLERS =====

    handleSearchTermChange(event) { this.searchTerm = event.target.value; }
    handleCategoryFilterChange(event) { this.categoryFilter = event.detail.value; }

    async handleSearch() {
        if (this.isSearchDisabled) return;

        this.isLoading = true;
        this.showSearchResults = true;

        try {
            const results = await searchProducts({
                searchTerm: this.searchTerm,
                pricebookId: this.pricebookId,
                category: this.categoryFilter || null
            });

            this.searchResults = results.map(r => ({
                ...r,
                formattedPrice: this.formatCurrency(r.unitPrice),
                formattedTax: r.taxPercent != null ? r.taxPercent + '%' : '0%'
            }));
        } catch (error) {
            this.showError('Search failed', this.reduceErrors(error));
            this.searchResults = [];
        } finally {
            this.isLoading = false;
        }
    }

    // ===== ADD / REMOVE LINE ITEMS =====

    handleAddProduct(event) {
        const pbeId = event.currentTarget.dataset.id;
        const product = this.searchResults.find(p => p.pricebookEntryId === pbeId);
        if (!product) return;

        // Check for duplicate
        const exists = this.lineItems.find(item => item.pricebookEntryId === pbeId);
        if (exists) {
            this.showError('Duplicate Product', 'This product is already in the quote. Update the quantity instead.');
            return;
        }

        rowCounter++;
        const newItem = {
            rowId: 'row-' + rowCounter,
            rowNumber: this.lineItems.length + 1,
            productId: product.productId,
            pricebookEntryId: product.pricebookEntryId,
            productName: product.productName,
            productCode: product.productCode,
            uom: product.uom || 'Nos',
            quantity: 1,
            unitPrice: product.unitPrice,
            discount: 0,
            taxPercent: product.taxPercent || 0,
            taxType: 'GST',
            lineTotal: product.unitPrice,
            lineDescription: product.lineDescription || '',
            detailedDescription: product.detailedDescription || ''
        };

        this.lineItems = [...this.lineItems, newItem];
        this.showSuccess('Product Added', product.productName + ' added to the quote.');
    }

    handleRemoveLineItem(event) {
        const rowId = event.currentTarget.dataset.rowId;
        this.lineItems = this.lineItems
            .filter(item => item.rowId !== rowId)
            .map((item, index) => ({ ...item, rowNumber: index + 1 }));
    }

    handleLineItemChange(event) {
        const rowId = event.currentTarget.dataset.rowId;
        const field = event.currentTarget.dataset.field;
        let value = field === 'taxType' ? event.detail.value : event.target.value;

        this.lineItems = this.lineItems.map(item => {
            if (item.rowId === rowId) {
                const updated = { ...item };

                if (field === 'quantity') {
                    updated.quantity = parseFloat(value) || 0;
                } else if (field === 'discount') {
                    updated.discount = parseFloat(value) || 0;
                } else if (field === 'taxType') {
                    updated.taxType = value;
                }

                // Recalculate line total
                const base = updated.unitPrice * updated.quantity;
                const discountAmt = base * (updated.discount / 100);
                const afterDiscount = base - discountAmt;
                const taxAmt = updated.taxType === 'Exempt' ? 0 : afterDiscount * ((updated.taxPercent || 0) / 100);
                updated.lineTotal = afterDiscount + taxAmt;

                return updated;
            }
            return item;
        });
    }

    // ===== CHARGE HANDLERS =====

    handleChargeChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = parseFloat(event.target.value) || 0;
    }

    // ===== SAVE =====

    async handleSave() {
        // Validate required fields
        const errors = this.validateForm();
        if (errors.length > 0) {
            this.showError('Validation Error', errors.join('\n'));
            return;
        }

        this.isSaving = true;
        this.isLoading = true;

        try {
            const quoteHeader = {
                name: this.quoteName,
                opportunityId: this.recordId,
                pricebookId: this.pricebookId,
                quoteDate: this.quoteDate,
                validTill: this.validTillDate,
                billingAddress: this.billingAddress,
                shippingAddress: this.shippingAddress,
                shippingMode: this.shippingMode,
                vertical: this.vertical,
                isActive: this.isActive
            };

            const lineItemsPayload = this.lineItems.map(item => ({
                productId: item.productId,
                pricebookEntryId: item.pricebookEntryId,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: item.discount,
                taxType: item.taxType,
                lineDescription: item.lineDescription,
                detailedDescription: item.detailedDescription
            }));

            const chargesPayload = {
                shippingCharges: this.shippingCharges,
                transportCharges: this.transportCharges,
                warrantyCost: this.warrantyCost,
                installationCost: this.installationCost,
                packingCharges: this.packingCharges,
                trainingCost: this.trainingCost,
                taxAmount: this.totalTax
            };

            const quoteId = await saveQuoteWithLineItems({
                quoteJSON: JSON.stringify(quoteHeader),
                lineItemsJSON: JSON.stringify(lineItemsPayload),
                chargesJSON: JSON.stringify(chargesPayload)
            });

            this.showSuccess('Quote Created', 'Quote has been created successfully.');

            // Navigate to the new Quote record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: quoteId,
                    objectApiName: 'Quote',
                    actionName: 'view'
                }
            });
        } catch (error) {
            this.showError('Save Failed', this.reduceErrors(error));
        } finally {
            this.isSaving = false;
            this.isLoading = false;
        }
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                objectApiName: 'Opportunity',
                actionName: 'view'
            }
        });
    }

    // ===== VALIDATION =====

    validateForm() {
        const errors = [];

        if (!this.quoteName) errors.push('Quote Name is required.');
        if (!this.quoteDate) errors.push('Quote Date is required.');
        if (!this.validTillDays) errors.push('Valid Till (Days) is required.');
        if (!this.vertical) errors.push('Vertical is required.');
        if (!this.billingAddress) errors.push('Billing Address is required.');
        if (!this.shippingAddress) errors.push('Shipping Address is required.');

        if (this.lineItems.length === 0) {
            errors.push('At least one line item is required.');
        }

        for (const item of this.lineItems) {
            if (!item.quantity || item.quantity <= 0) {
                errors.push(`Quantity for "${item.productName}" must be greater than 0.`);
            }
            if (item.discount < 0 || item.discount > 100) {
                errors.push(`Discount for "${item.productName}" must be between 0 and 100.`);
            }
            if (!item.unitPrice || item.unitPrice <= 0) {
                errors.push(`Unit price for "${item.productName}" is not available. Please check the Price Book.`);
            }
        }

        return errors;
    }

    // ===== UTILITY =====

    formatCurrency(value) {
        if (value == null) return '0.00';
        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: this.currencyCode || 'INR',
            minimumFractionDigits: 2
        }).format(value);
    }

    reduceErrors(error) {
        if (typeof error === 'string') return error;
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (Array.isArray(error?.body)) return error.body.map(e => e.message).join(', ');
        return 'An unexpected error occurred.';
    }

    showSuccess(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'success' }));
    }

    showError(title, message) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant: 'error', mode: 'sticky' }));
    }
}
