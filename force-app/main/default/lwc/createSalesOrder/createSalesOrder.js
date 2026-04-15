import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteDetails from '@salesforce/apex/CreateSalesOrderController.getQuoteDetails';
import getWarehouses from '@salesforce/apex/CreateSalesOrderController.getWarehouses';
import getPricebookProducts from '@salesforce/apex/CreateSalesOrderController.getPricebookProducts';
import createSalesOrder from '@salesforce/apex/CreateSalesOrderController.createSalesOrder';

export default class CreateSalesOrder extends NavigationMixin(LightningElement) {
    @api recordId;

    isLoading = true;
    isSaving = false;

    @track quoteContext = {};
    @track warehouseOptions = [];
    @track displayItems = [];
    @track productOptions = [];
    @track productCatalog = []; // full ProductOption records (label/value/unitPrice/tax)

    @track deliveryCommittedDate;
    @track warehouseId = '';
    @track remarks = '';
    @track creditOrder = false;

    // Add Product sub-modal state
    @track isAddProductOpen = false;
    @track newPricebookEntryId = '';
    @track newQuantity = 1;
    @track newDiscount = 0;

    @wire(getQuoteDetails, { quoteId: '$recordId' })
    wiredQuote({ error, data }) {
        if (data) {
            this.quoteContext = data;
            this.displayItems = (data.items || []).map((it) => {
                const qty = it.quantity || 0;
                const price = it.unitPrice || 0;
                const disc = it.discount || 0;
                const total = this.calcTotal(qty, price, disc);
                return {
                    ...it,
                    source: 'quote',
                    quantity: qty,
                    discount: disc,
                    stockQty: 0,
                    stockQtyDisplay: '0',
                    syncing: false,
                    unitPriceDisplay: this.formatCurrency(price),
                    totalPrice: total,
                    totalPriceDisplay: this.formatCurrency(total),
                    rowKey: it.lineId
                };
            });
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

    @wire(getPricebookProducts, { quoteId: '$recordId' })
    wiredProducts({ error, data }) {
        if (data) {
            this.productCatalog = data;
            this.productOptions = data.map((p) => ({
                label: p.label,
                value: p.value
            }));
        } else if (error) {
            this.showToast('Warning', 'Could not load products.', 'warning');
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
        return this.isSaving;
    }

    get backgroundClass() {
        return this.isAddProductOpen ? 'blur-background' : '';
    }

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
        const isoMatch = s.match(/^(\d{4})-(\d{2})-(\d{2})/);
        if (isoMatch) return `${isoMatch[1]}-${isoMatch[2]}-${isoMatch[3]}`;
        const d = new Date(s);
        if (!isNaN(d.getTime())) {
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const day = String(d.getDate()).padStart(2, '0');
            return `${y}-${m}-${day}`;
        }
        return null;
    }

    calcTotal(qty, unitPrice, discountPercent) {
        const q = Number(qty) || 0;
        const p = Number(unitPrice) || 0;
        const d = Number(discountPercent) || 0;
        return q * p * (1 - d / 100);
    }

    handleDeliveryDateChange(event) {
        this.deliveryCommittedDate = this.toIsoDate(event.detail.value);
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

    handleQuantityChange(event) {
        const rowKey = event.target.dataset.rowKey;
        const qty = parseFloat(event.target.value);
        this.displayItems = this.displayItems.map((it) => {
            if (it.rowKey !== rowKey) return it;
            const newQty = isNaN(qty) ? it.quantity : qty;
            const total = this.calcTotal(newQty, it.unitPrice, it.discount);
            return {
                ...it,
                quantity: newQty,
                totalPrice: total,
                totalPriceDisplay: this.formatCurrency(total)
            };
        });
    }

    handleDiscountChange(event) {
        const rowKey = event.target.dataset.rowKey;
        const rawDisc = parseFloat(event.target.value);
        const disc = isNaN(rawDisc) ? 0 : Math.max(0, Math.min(100, rawDisc));
        this.displayItems = this.displayItems.map((it) => {
            if (it.rowKey !== rowKey) return it;
            const total = this.calcTotal(it.quantity, it.unitPrice, disc);
            return {
                ...it,
                discount: disc,
                totalPrice: total,
                totalPriceDisplay: this.formatCurrency(total)
            };
        });
    }

    handleDeleteRow(event) {
        const rowKey = event.target.dataset.rowKey;
        this.displayItems = this.displayItems.filter((it) => it.rowKey !== rowKey);
    }

    // ===== Add Product sub-modal =====

    handleOpenAddProduct() {
        this.newPricebookEntryId = '';
        this.newQuantity = 1;
        this.newDiscount = 0;
        this.isAddProductOpen = true;
    }

    handleCloseAddProduct() {
        this.isAddProductOpen = false;
    }

    handleNewProductChange(event) {
        this.newPricebookEntryId = event.detail.value;
    }

    handleNewQuantityChange(event) {
        const q = parseFloat(event.target.value);
        this.newQuantity = isNaN(q) ? 1 : Math.max(1, q);
    }

    handleNewDiscountChange(event) {
        const d = parseFloat(event.target.value);
        this.newDiscount = isNaN(d) ? 0 : Math.max(0, Math.min(100, d));
    }

    handleAddProduct() {
        if (!this.newPricebookEntryId) {
            this.showToast('Error', 'Please pick a product to add.', 'error');
            return;
        }
        const cat = this.productCatalog.find((p) => p.value === this.newPricebookEntryId);
        if (!cat) {
            this.showToast('Error', 'Selected product is not available.', 'error');
            return;
        }
        // Reject duplicates (same PricebookEntry already on the list).
        if (this.displayItems.some(
            (it) => it.source === 'manual' && it.pricebookEntryId === cat.value
        )) {
            this.showToast('Warning', 'This product is already in the order.', 'warning');
            return;
        }
        const qty = Number(this.newQuantity) || 1;
        const disc = Number(this.newDiscount) || 0;
        const total = this.calcTotal(qty, cat.unitPrice, disc);
        const rowKey = 'manual-' + cat.value;
        this.displayItems = [
            ...this.displayItems,
            {
                source: 'manual',
                rowKey: rowKey,
                lineId: null,
                pricebookEntryId: cat.value,
                productId: cat.productId,
                productName: cat.productName,
                quantity: qty,
                unitPrice: cat.unitPrice,
                unitPriceDisplay: this.formatCurrency(cat.unitPrice),
                discount: disc,
                totalPrice: total,
                totalPriceDisplay: this.formatCurrency(total),
                stockQty: 0,
                stockQtyDisplay: '0',
                tax: cat.tax
            }
        ];
        this.isAddProductOpen = false;
    }

    async handleConfirm() {
        if (this.isSaving) return;

        const dateEl = this.template.querySelector(
            'lightning-input[data-field="deliveryCommittedDate"]'
        );
        const domIso = this.toIsoDate(dateEl ? dateEl.value : null);
        const stateIso = this.toIsoDate(this.deliveryCommittedDate);
        const finalIso = stateIso || domIso;
        if (finalIso && finalIso !== this.deliveryCommittedDate) {
            this.deliveryCommittedDate = finalIso;
        }

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
            this.showToast(
                'Error',
                'Delivery Committed Date cannot be in the past',
                'error'
            );
            return;
        }

        if (!this.displayItems.length) {
            this.showToast(
                'Error',
                'Please add at least one product to the Sales Order',
                'error'
            );
            return;
        }

        // Split items into Quote-sourced vs manually-added.
        const quoteItems = this.displayItems.filter((i) => i.source === 'quote');
        const manualItems = this.displayItems.filter((i) => i.source === 'manual');

        this.isSaving = true;
        try {
            const selectedLineIds = quoteItems.map((i) => i.lineId);
            const quantityByLineId = {};
            const discountByLineId = {};
            quoteItems.forEach((i) => {
                quantityByLineId[i.lineId] = i.quantity;
                discountByLineId[i.lineId] = i.discount || 0;
            });

            const manualPricebookEntryIds = manualItems.map((i) => i.pricebookEntryId);
            const manualQuantityByPbeId = {};
            const manualDiscountByPbeId = {};
            manualItems.forEach((i) => {
                manualQuantityByPbeId[i.pricebookEntryId] = i.quantity;
                manualDiscountByPbeId[i.pricebookEntryId] = i.discount || 0;
            });

            const orderId = await createSalesOrder({
                quoteId: this.recordId,
                deliveryCommittedDate: finalIso,
                warehouseId: this.warehouseId,
                remarks: this.remarks,
                creditOrder: this.creditOrder === true,
                selectedLineIds: selectedLineIds,
                quantityByLineId: quantityByLineId,
                discountByLineId: discountByLineId,
                manualPricebookEntryIds: manualPricebookEntryIds,
                manualQuantityByPbeId: manualQuantityByPbeId,
                manualDiscountByPbeId: manualDiscountByPbeId
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
