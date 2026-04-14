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
        return (
            this.isSaving ||
            !this.warehouseId ||
            !this.deliveryCommittedDate ||
            !this.displayItems.some((i) => i.selected)
        );
    }

    handleDeliveryDateChange(event) {
        this.deliveryCommittedDate = event.detail.value;
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

        if (!this.warehouseId) {
            this.showToast('Error', 'Please select a Warehouse', 'error');
            return;
        }

        if (!this.deliveryCommittedDate) {
            this.showToast('Error', 'Delivery Committed Date is required', 'error');
            return;
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const selectedDate = new Date(this.deliveryCommittedDate + 'T00:00:00');
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
            const input = {
                deliveryCommittedDate: this.deliveryCommittedDate,
                warehouseId: this.warehouseId,
                remarks: this.remarks,
                creditOrder: this.creditOrder === true,
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
