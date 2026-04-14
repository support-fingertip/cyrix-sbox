import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteDetails from '@salesforce/apex/CreateSalesOrderController.getQuoteDetails';
import getWarehouses from '@salesforce/apex/CreateSalesOrderController.getWarehouses';
import createSalesOrder from '@salesforce/apex/CreateSalesOrderController.createSalesOrder';

export default class CreateSalesOrder extends NavigationMixin(LightningElement) {
    @api recordId;

    isLoading = true;
    isSaving = false;

    @track quoteContext = {};
    @track warehouseOptions = [];
    @track displayItems = [];

    @track form = {
        deliveryCommittedDate: null,
        warehouseId: '',
        remarks: '',
        creditOrder: false
    };

    @wire(getQuoteDetails, { quoteId: '$recordId' })
    wiredQuote({ error, data }) {
        if (data) {
            this.quoteContext = data;
            this.displayItems = (data.items || []).map((it) => ({
                ...it,
                selected: true,
                quantity: it.quantity,
                stockQty: 0,
                stockQtyDisplay: '0',
                syncing: false,
                unitPriceDisplay: this.formatCurrency(it.unitPrice),
                totalPriceDisplay: this.formatCurrency(it.totalPrice)
            }));
            this.isLoading = false;
        } else if (error) {
            this.isLoading = false;
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    @wire(getWarehouses)
    wiredWarehouses({ error, data }) {
        if (data) {
            this.warehouseOptions = data;
        } else if (error) {
            this.showToast('Warning', 'Could not load warehouses.', 'warning');
        }
    }

    get hasItems() {
        return this.displayItems && this.displayItems.length > 0;
    }

    get emailDisplay() {
        return this.quoteContext.email || 'N/A';
    }

    get phoneDisplay() {
        return this.quoteContext.phone || 'N/A';
    }

    get shippingDisplay() {
        return this.quoteContext.shippingAddress || 'N/A';
    }

    get billingDisplay() {
        return this.quoteContext.billingAddress || 'N/A';
    }

    get confirmDisabled() {
        // Only gate on isSaving here. Required-field validation is performed
        // in handleConfirm using live DOM values to avoid stale-state lockouts.
        return this.isSaving;
    }

    handleInputChange(event) {
        const src = event.currentTarget || event.target;
        const field = src && src.dataset ? src.dataset.field : null;
        const value = (event.detail && event.detail.value !== undefined && event.detail.value !== null)
            ? event.detail.value
            : (src ? src.value : undefined);
        if (!field) return;
        this.form = { ...this.form, [field]: value };
    }

    handleToggleChange(event) {
        const src = event.currentTarget || event.target;
        const field = src && src.dataset ? src.dataset.field : null;
        const checked = (event.detail && event.detail.checked !== undefined)
            ? event.detail.checked
            : (src ? src.checked : false);
        if (!field) return;
        this.form = { ...this.form, [field]: checked };
    }

    handleItemSelect(event) {
        const lineId = event.target.dataset.lineId;
        const selected = event.target.checked;
        this.displayItems = this.displayItems.map((it) =>
            it.lineId === lineId ? { ...it, selected } : it
        );
    }

    handleQuantityChange(event) {
        const lineId = event.target.dataset.lineId;
        const qty = parseFloat(event.target.value);
        this.displayItems = this.displayItems.map((it) => {
            if (it.lineId !== lineId) return it;
            const newQty = isNaN(qty) ? it.quantity : qty;
            const newTotal = newQty * (it.unitPrice || 0);
            return {
                ...it,
                quantity: newQty,
                totalPriceDisplay: this.formatCurrency(newTotal)
            };
        });
    }

    async handleConfirm() {
        // Pull the current values directly from the DOM as the source of
        // truth. Relying on @track state alone has proven unreliable for
        // lightning-input type="date" — under some timing/retargeting
        // conditions the change handler does not update state even though
        // the input visibly holds a value, which caused the server-side
        // "Delivery Committed Date is required" error.
        const dateInput = this.template.querySelector('lightning-input[data-field="deliveryCommittedDate"]');
        const warehouseInput = this.template.querySelector('lightning-combobox[data-field="warehouseId"]');
        const remarksInput = this.template.querySelector('lightning-textarea[data-field="remarks"]');
        const creditToggle = this.template.querySelector('lightning-input[data-field="creditOrder"]');

        const rawDate = dateInput ? dateInput.value : this.form.deliveryCommittedDate;
        // Trim to catch whitespace/unparsed-placeholder values that are truthy
        // in JS but blank on the Apex side (String.isBlank), which would
        // otherwise surface as the server-side "Delivery Committed Date is
        // required" error despite this handler running.
        const deliveryCommittedDate = (rawDate == null ? '' : String(rawDate)).trim();
        const warehouseId = warehouseInput ? warehouseInput.value : this.form.warehouseId;
        const remarks = remarksInput ? remarksInput.value : this.form.remarks;
        const creditOrder = creditToggle ? creditToggle.checked : this.form.creditOrder;

        // Keep the tracked state in sync so reactive getters are accurate.
        this.form = {
            ...this.form,
            deliveryCommittedDate: deliveryCommittedDate || null,
            warehouseId,
            remarks,
            creditOrder
        };

        if (this.isSaving) return;

        // Require a non-blank ISO date string (YYYY-MM-DD). Also ask the input
        // to run its own validity check so the user sees the inline field
        // error, not just a toast.
        const isoDateOk = /^\d{4}-\d{2}-\d{2}$/.test(deliveryCommittedDate);
        const inputValid = dateInput && typeof dateInput.reportValidity === 'function'
            ? dateInput.reportValidity()
            : true;
        if (!deliveryCommittedDate || !isoDateOk || !inputValid) {
            this.showToast('Missing date', 'Please select a Delivery Committed Date.', 'warning');
            if (dateInput && dateInput.focus) dateInput.focus();
            return;
        }
        if (!warehouseId) {
            this.showToast('Missing warehouse', 'Please select a Warehouse.', 'warning');
            return;
        }

        const selected = this.displayItems.filter((i) => i.selected);
        if (selected.length === 0) {
            this.showToast('Missing items', 'Please select at least one quote item.', 'warning');
            return;
        }

        this.isSaving = true;
        try {
            const input = {
                deliveryCommittedDate: deliveryCommittedDate,
                warehouseId: warehouseId,
                remarks: remarks,
                creditOrder: creditOrder === true,
                selectedItems: selected.map((i) => ({
                    lineId: i.lineId,
                    quantity: i.quantity
                }))
            };

            const orderId = await createSalesOrder({
                quoteId: this.recordId,
                input: input
            });

            this.showToast('Success', 'Sales Order created.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: orderId,
                    objectApiName: 'Order',
                    actionName: 'view'
                }
            });
        } catch (err) {
            this.showToast('Error', this.reduceError(err), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    handleCheckStock() {
        // UI-only button for now. Wire to Apex when the stock data source is available.
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    formatCurrency(value) {
        if (value === null || value === undefined) return '';
        return Number(value).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(err) {
        if (!err) return 'Unknown error';
        if (typeof err === 'string') return err;
        if (err.body && err.body.message) return err.body.message;
        if (err.message) return err.message;
        return JSON.stringify(err);
    }
}