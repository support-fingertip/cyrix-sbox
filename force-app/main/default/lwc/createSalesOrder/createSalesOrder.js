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
        return (
            this.isSaving ||
            !this.form.deliveryCommittedDate ||
            !this.form.warehouseId ||
            !this.displayItems.some((i) => i.selected)
        );
    }

    handleInputChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = (event.detail && event.detail.value !== undefined)
            ? event.detail.value
            : event.target.value;
        if (!field) return;
        this.form = { ...this.form, [field]: value };
    }

    handleToggleChange(event) {
        const field = event.currentTarget.dataset.field;
        const checked = (event.detail && event.detail.checked !== undefined)
            ? event.detail.checked
            : event.target.checked;
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
        if (this.confirmDisabled) return;

        const selected = this.displayItems.filter((i) => i.selected);
        if (selected.length === 0) {
            this.showToast('Missing items', 'Please select at least one quote item.', 'warning');
            return;
        }

        this.isSaving = true;
        try {
            const input = {
                deliveryCommittedDate: this.form.deliveryCommittedDate,
                warehouseId: this.form.warehouseId,
                remarks: this.form.remarks,
                creditOrder: this.form.creditOrder,
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