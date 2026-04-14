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

    @track deliveryCommittedDate;
    @track warehouseId = '';
    @track remarks = '';
    @track creditOrder = false;

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

    get isConfirmDisabled() {
        // Only gate on isSaving. Field-level validation (and DOM fallback
        // for the date input) is handled inside handleConfirm.
        return this.isSaving;
    }

    // Coerce any value coming back from lightning-input type="date"
    // (string, Date object, locale-formatted text) into a strict
    // YYYY-MM-DD ISO string, or null if it can't be parsed.
    toIsoDate(raw) {
        if (raw == null) return null;
        if (raw instanceof Date && !isNaN(raw.getTime())) {
            const y = raw.getFullYear();
            const m = String(raw.getMonth() + 1).padStart(2, '0');
            const d = String(raw.getDate()).padStart(2, '0');
            return `${y}-${m}-${d}`;
        }
        const s = String(raw).trim();
        if (!s) return null;
        // Already ISO: accept the date portion.
        const isoMatch = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
        if (isoMatch) return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
        // Try native Date parse (covers locale formats like "19-Apr-2026").
        const d = new Date(s);
        if (!isNaN(d.getTime())) {
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            return `${y}-${m}-${day}`;
        }
        return null;
    }

    handleDeliveryDateChange(event) {
        const raw = event.detail.value;
        const iso = this.toIsoDate(raw);
        this.deliveryCommittedDate = iso;
        // eslint-disable-next-line no-console
        console.log('[CreateSalesOrder] date change raw=', raw, 'typeof=', typeof raw, 'iso=', iso);
    }

    handleWarehouseChange(event) {
        this.warehouseId = event.detail.value;
    }

    handleRemarksChange(event) {
        this.remarks = event.target.value;
    }

    handleCreditToggle(event) {
        this.creditOrder = event.target.checked;
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
        if (this.isSaving) return;

        // DOM fallback: re-read the date straight from lightning-input in
        // case the @track state missed the change event for any reason.
        const dateEl = this.template.querySelector('lightning-input[data-field="deliveryCommittedDate"]');
        const domRaw = dateEl ? dateEl.value : null;
        const domIso = this.toIsoDate(domRaw);
        const stateIso = this.toIsoDate(this.deliveryCommittedDate);
        const finalIso = stateIso || domIso;
        if (finalIso && finalIso !== this.deliveryCommittedDate) {
            this.deliveryCommittedDate = finalIso;
        }

        // Log as a JSON string so LWS proxies don't hide the values.
        // eslint-disable-next-line no-console
        console.log(
            '[CreateSalesOrder] handleConfirm state: ' +
                JSON.stringify({
                    stateRaw: this.deliveryCommittedDate,
                    stateType: typeof this.deliveryCommittedDate,
                    domRaw: domRaw,
                    domType: typeof domRaw,
                    stateIso: stateIso,
                    domIso: domIso,
                    finalIso: finalIso,
                    warehouseId: this.warehouseId,
                    selectedCount: this.displayItems.filter((i) => i.selected).length
                })
        );

        if (!this.warehouseId) {
            this.showToast('Error', 'Please select a Warehouse', 'error');
            return;
        }

        if (!finalIso) {
            this.showToast('Error', 'Delivery Committed Date is required', 'error');
            if (dateEl && dateEl.focus) dateEl.focus();
            return;
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const selectedDate = new Date(finalIso + 'T00:00:00');
        if (selectedDate < today) {
            this.showToast('Error', 'Delivery Committed Date cannot be in the past', 'error');
            return;
        }

        const selected = this.displayItems.filter((i) => i.selected);
        if (selected.length === 0) {
            this.showToast('Error', 'Please select at least one quote item', 'error');
            return;
        }

        this.isSaving = true;
        try {
            const selectedLineIds = selected.map((i) => i.lineId);
            const quantityByLineId = {};
            selected.forEach((i) => {
                quantityByLineId[i.lineId] = i.quantity;
            });

            const orderId = await createSalesOrder({
                quoteId: this.recordId,
                deliveryCommittedDate: finalIso,
                warehouseId: this.warehouseId,
                remarks: this.remarks,
                creditOrder: this.creditOrder === true,
                selectedLineIds: selectedLineIds,
                quantityByLineId: quantityByLineId
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
