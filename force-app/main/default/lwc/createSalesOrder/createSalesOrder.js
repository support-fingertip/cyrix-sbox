import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import getQuoteDetails from '@salesforce/apex/CreateSalesOrderController.getQuoteDetails';
import getPricebookProducts from '@salesforce/apex/CreateSalesOrderController.getPricebookProducts';
import createSalesOrder from '@salesforce/apex/CreateSalesOrderController.createSalesOrder';

export default class CreateSalesOrder extends NavigationMixin(LightningElement) {
    @api recordId;

    isLoading = true;
    isSaving = false;

    connectedCallback() {
        this._widenQuickActionModal();
    }

    renderedCallback() {
        this._widenQuickActionModal();
    }

    _widenQuickActionModal() {
        try {
            const container =
                this.template.host &&
                this.template.host.closest &&
                this.template.host.closest('.slds-modal__container');
            if (!container) return;
            if (container.dataset.csoResized === '1') return;
            container.style.width = '95vw';
            container.style.maxWidth = '1600px';
            container.style.height = 'auto';
            container.style.maxHeight = '92vh';
            container.dataset.csoResized = '1';
        } catch (e) {
            // Ignore — modal sizing is a nice-to-have, not a blocker.
        }
    }

    @track quoteContext = {};
    @track displayItems = [];
    @track productOptions = [];
    @track productCatalog = [];

    @track remarks = '';

    @track isAddProductOpen = false;
    @track newPricebookEntryId = '';
    @track newQuantity = 1;
    @track newDiscount = 0;

    @wire(getQuoteDetails, { quoteId: '$recordId' })
    wiredQuote({ error, data }) {
        if (data) {
            this.quoteContext = data;
            this.displayItems = (data.items || []).map((it, idx) => {
                const qty = it.quantity || 0;
                const price = it.unitPrice || 0;
                const disc = it.discount || 0;
                const total = this.calcTotal(qty, price, disc);
                return {
                    ...it,
                    source: 'quote',
                    rowNum: idx + 1,
                    quantity: qty,
                    discount: disc,
                    uomDisplay: it.uom || 'Nos',
                    listPriceDisplay: this.formatCurrency(it.listPrice),
                    unitPriceDisplay: this.formatCurrency(price),
                    taxDisplay: it.tax != null ? Number(it.tax).toFixed(0) + '%' : '-',
                    priceStatusBadgeClass: this.priceStatusBadge(it.priceStatus),
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

    @wire(getPricebookProducts, { quoteId: '$recordId' })
    wiredProducts({ error, data }) {
        if (data) {
            this.productCatalog = data;
            this.productOptions = data.map((p) => ({ label: p.label, value: p.value }));
        } else if (error) {
            this.showToast('Warning', 'Could not load products.', 'warning');
        }
    }

    // ===== Getters for Quote Information display =====

    get hasItems() {
        return this.displayItems && this.displayItems.length > 0;
    }

    get quoteDateDisplay() {
        return this.formatDate(this.quoteContext.quoteDate) || 'N/A';
    }

    get validTillDaysDisplay() {
        return this.quoteContext.quoteValidTillInDays || 'N/A';
    }

    get opportunityNameDisplay() {
        return this.quoteContext.opportunityName || 'N/A';
    }

    get businessVerticalDisplay() {
        return this.quoteContext.businessVertical || this.quoteContext.vertical || 'N/A';
    }

    get shippingModeDisplay() {
        return this.quoteContext.shippingMode || 'N/A';
    }

    get deliveryDisplay() {
        return this.quoteContext.delivery || 'N/A';
    }

    get contractPeriodFromDisplay() {
        return this.formatDate(this.quoteContext.contractPeriodFromDate) || 'N/A';
    }

    get contractPeriodEndDisplay() {
        return this.formatDate(this.quoteContext.contractPeriodEndDate) || 'N/A';
    }

    get statusDisplay() {
        return this.quoteContext.status || 'N/A';
    }

    get hasPaymentTerms() {
        return !!(this.quoteContext && this.quoteContext.paymentTerms && String(this.quoteContext.paymentTerms).trim().length);
    }

    // ===== Getters for Bill To / Ship To =====

    get billToNameDisplay()       { return this.quoteContext.billToName || this.quoteContext.customerName || 'N/A'; }
    get billToStreetDisplay()     { return this.quoteContext.billToStreet || 'N/A'; }
    get billToCityDisplay()       { return this.quoteContext.billToCity || 'N/A'; }
    get billToStateDisplay()      { return this.quoteContext.billToState || 'N/A'; }
    get billToPostalCodeDisplay() { return this.quoteContext.billToPostalCode || 'N/A'; }
    get billToCountryDisplay()    { return this.quoteContext.billToCountry || 'N/A'; }

    get shipToNameDisplay()       { return this.quoteContext.shipToName || this.quoteContext.customerName || 'N/A'; }
    get shipToStreetDisplay()     { return this.quoteContext.shipToStreet || 'N/A'; }
    get shipToCityDisplay()       { return this.quoteContext.shipToCity || 'N/A'; }
    get shipToStateDisplay()      { return this.quoteContext.shipToState || 'N/A'; }
    get shipToPostalCodeDisplay() { return this.quoteContext.shipToPostalCode || 'N/A'; }
    get shipToCountryDisplay()    { return this.quoteContext.shipToCountry || 'N/A'; }

    get isConfirmDisabled() {
        return this.isSaving;
    }

    get addProductButtonLabel() {
        return this.isAddProductOpen ? 'Close' : 'Add Product';
    }

    // ===== Helpers =====

    calcTotal(qty, unitPrice, discountPercent) {
        const q = Number(qty) || 0;
        const p = Number(unitPrice) || 0;
        const d = Number(discountPercent) || 0;
        return q * p * (1 - d / 100);
    }

    priceStatusBadge(status) {
        if (!status) return 'cso-badge cso-badge-neutral';
        const s = String(status).toLowerCase();
        if (s.indexOf('approval') !== -1) return 'cso-badge cso-badge-warn';
        if (s === 'approved')             return 'cso-badge cso-badge-ok';
        if (s === 'rejected')             return 'cso-badge cso-badge-error';
        return 'cso-badge cso-badge-neutral';
    }

    formatCurrency(value) {
        if (value === null || value === undefined) return '';
        return Number(value).toLocaleString('en-IN', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    formatDate(iso) {
        if (!iso) return null;
        try {
            const d = new Date(iso);
            if (isNaN(d.getTime())) return iso;
            const day = String(d.getDate()).padStart(2, '0');
            const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            return `${day}-${months[d.getMonth()]}-${d.getFullYear()}`;
        } catch (e) {
            return String(iso);
        }
    }

    // ===== Handlers =====

    handleRemarksChange(event) {
        this.remarks = event.target.value;
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
        this.displayItems = this.displayItems
            .filter((it) => it.rowKey !== rowKey)
            .map((it, idx) => ({ ...it, rowNum: idx + 1 }));
    }

    handleToggleAddProduct() {
        if (this.isAddProductOpen) {
            this.isAddProductOpen = false;
            return;
        }
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
        if (this.displayItems.some(
            (it) => it.source === 'manual' && it.pricebookEntryId === cat.value
        )) {
            this.showToast('Warning', 'This product is already in the order.', 'warning');
            return;
        }
        const qty = Number(this.newQuantity) || 1;
        const disc = Number(this.newDiscount) || 0;
        const unitPrice = cat.unitPrice;
        const listPrice = cat.listPrice != null ? cat.listPrice : unitPrice;
        const total = this.calcTotal(qty, unitPrice, disc);
        const rowKey = 'manual-' + cat.value;
        const nextRowNum = this.displayItems.length + 1;
        this.displayItems = [
            ...this.displayItems,
            {
                source: 'manual',
                rowKey: rowKey,
                rowNum: nextRowNum,
                lineId: null,
                pricebookEntryId: cat.value,
                pricebookName: null,
                productId: cat.productId,
                productName: cat.productName,
                productCode: cat.productCode,
                uom: cat.uom,
                uomDisplay: cat.uom || 'Nos',
                quantity: qty,
                unitPrice: unitPrice,
                unitPriceDisplay: this.formatCurrency(unitPrice),
                listPrice: listPrice,
                listPriceDisplay: this.formatCurrency(listPrice),
                discount: disc,
                totalPrice: total,
                totalPriceDisplay: this.formatCurrency(total),
                tax: cat.tax,
                taxDisplay: cat.tax != null ? Number(cat.tax).toFixed(0) + '%' : '-',
                priceStatus: null,
                priceStatusBadgeClass: this.priceStatusBadge(null)
            }
        ];
        this.isAddProductOpen = false;
    }

    async handleConfirm() {
        if (this.isSaving) return;

        if (!this.displayItems.length) {
            this.showToast('Error', 'Please add at least one product to the Sales Order', 'error');
            return;
        }

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
                remarks: this.remarks,
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

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
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