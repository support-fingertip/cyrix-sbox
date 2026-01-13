import { LightningElement, api, track, wire } from 'lwc';
import getExpenseLineItems from '@salesforce/apex/ExpenseApprovalController.getExpenseLineItems';
import getExpenseDetails from '@salesforce/apex/ExpenseApprovalController.getExpenseDetails';
import updateExpenseLineItems from '@salesforce/apex/ExpenseApprovalController.updateExpenseLineItems';
import approveExpenseItems from '@salesforce/apex/ExpenseApprovalController.approveExpenseItems';
import rejectExpenses from '@salesforce/apex/ExpenseApprovalController.rejectExpenses';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';

export default class ExpenseApproveUI extends NavigationMixin(LightningElement) {
    @api recordId;

    @track data = [];
    @track selectedRows = [];
    @track draftValues = [];
    @track showSaveButton = false;

    @track hasSelectableRows = false;
    isAllSelected = false;

    expenseTitle = 'Expense Approval';
    currentUserId = USER_ID;

    isOpenedByOwner = false;
    isOpenedByAdmin = false;

    approvalComments = '';
isspinner = false;
    expense = {};
    expenseApprovers = { L1: null, Finance: null };

    wiredDataResult;
    wiredExpenseResult;

    approvedLimitAutoAmt = 0;
    approvedLimitCarKM = 0;
    approvedLimitBikeKM = 0;

    submittedLimitAutoAmt = 0;
    submittedLimitCarKM = 0;
    submittedLimitBikeKM = 0;

    totalLimitAutoAmt = 0;
    totalLimitCarKM = 0;
    totalLimitBikeKM = 0;
isLoading =false;
    taLimitBikeKM = 0;
    taLimitCarKM = 0;
    taLimitAutoAmt = 0;

    isCarEnabled = false;
    isBikeEnabled = false;
    isAutoEnabled = false;

    // ---------- WIRES ----------
    @wire(getExpenseDetails, { expenseId: '$recordId' })
    wiredExpense(result) {
        this.wiredExpenseResult = result;
        const { data, error } = result;

        if (data) {
            this.isOpenedByOwner = !data.isOpenedByAdmin && data.isOpenedByOwner;
            this.isOpenedByAdmin = !!data.isOpenedByAdmin;

            this.expenseApprovers = {
                L1: data.expense?.Expense_Approver_L1__c || null,
                Finance: data.expense?.Expense_Finance_Department_Approver__c || null
            };
        } else if (error) {
            // Don’t toast here unless you want spam on load
            // just log it
            // eslint-disable-next-line no-console
            console.error('Expense detail error', error);
        }
    }

    @wire(getExpenseLineItems, { recordId: '$recordId' })
    wiredExpenseLineItems(result) {
        this.wiredDataResult = result;
        const { data, error } = result;

        if (data) {
            this.hasSelectableRows = false;
            this.isAllSelected = false;
            this.selectedRows = [];
            this.draftValues = [];
            this.showSaveButton = false;

            // custom order mapping
            const expenseTypeOrder = {
                TA: 1,
                DA: 2,
                Food: 3,
                'Accommodation': 4,
                'Lodging + Food': 5,
                'Local Conveyance': 6,
                'Courier Charges': 7,
                'Mobile Charges': 8,
                'Transport Conveyance': 9,
                'Other/MISC': 10
            };

            this.expense = data.expense || {};

            // header stats
            this.approvedLimitAutoAmt = this.expense.totalApprovedTAAuto__c || 0;
            this.approvedLimitCarKM = this.expense.totalApprovedTACar__c || 0;
            this.approvedLimitBikeKM = this.expense.totalApprovedTABike__c || 0;

            this.submittedLimitAutoAmt = this.expense.totalSubmittedTAAuto__c || 0;
            this.submittedLimitCarKM = this.expense.totalSubmittedTACar__c || 0;
            this.submittedLimitBikeKM = this.expense.totalSubmittedTABike__c || 0;

            this.totalLimitAutoAmt = this.expense.Total_Amount_Auto__c || 0;
            this.totalLimitCarKM = this.expense.Total_KM_Car__c || 0;
            this.totalLimitBikeKM = this.expense.Total_KM_Bike__c || 0;

            if (data.travelEligibile) {
                this.taLimitBikeKM = data.travelEligibile.Monthly_limit_Bike__c || 0;
                this.taLimitCarKM = data.travelEligibile.Monthly_Limit_Car__c || 0;
                this.taLimitAutoAmt = data.travelEligibile.Monthly_limit_Auto__c || 0;

                this.isCarEnabled = !!data.isCarEnabled;
                this.isBikeEnabled = !!data.isBikeEnabled;
                this.isAutoEnabled = !!data.isAutoEnabled;
            } else {
                this.taLimitBikeKM = 0;
                this.taLimitCarKM = 0;
                this.taLimitAutoAmt = 0;

                this.isCarEnabled = false;
                this.isBikeEnabled = false;
                this.isAutoEnabled = false;
            }

            const rows = (data.result || [])
                .map((row) => this.processRow(row))
                .sort((a, b) => {
                    // Sort by expDate (latest first)
                    const dateA = new Date(a.expDate);
                    const dateB = new Date(b.expDate);
                    if (dateA.getTime() !== dateB.getTime()) {
                        return dateB - dateA;
                    }

                    // Then by expType order
                    const orderA = expenseTypeOrder[a.expType] || 999;
                    const orderB = expenseTypeOrder[b.expType] || 999;
                    return orderA - orderB;
                });

            // Because processRow can flip hasSelectableRows, reset it and recompute safely
            this.hasSelectableRows = rows.some((r) => r.isSelectable);

            // set final rows
            this.data = rows;

        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('Error loading expense lines:', error);
        }
    }

    // ---------- GETTERS ----------
  

    get showActionBar() {
        // Owner should not approve/reject
        return this.hasSelectableRows && !this.isOpenedByOwner;
    }

    get autoStats() {
        return [
            { label: 'TA Limit Auto', value: this.taLimitAutoAmt, valueClass: 'ta-value error' },
            { label: 'Total TA Auto', value: this.totalLimitAutoAmt, valueClass: 'ta-value success' },
            { label: 'Submitted TA Auto', value: this.submittedLimitAutoAmt, valueClass: 'ta-value success' },
            { label: 'Approved TA Auto', value: this.approvedLimitAutoAmt, valueClass: 'ta-value success' }
        ];
    }

    get carStats() {
        return [
            { label: 'TA Limit Car', value: this.taLimitCarKM, valueClass: 'ta-value error' },
            { label: 'Total TA Car', value: this.totalLimitCarKM, valueClass: 'ta-value success' },
            { label: 'Submitted TA Car', value: this.submittedLimitCarKM, valueClass: 'ta-value success' },
            { label: 'Approved TA Car', value: this.approvedLimitCarKM, valueClass: 'ta-value success' }
        ];
    }

    get bikeStats() {
        return [
            { label: 'TA Limit Bike', value: this.taLimitBikeKM, valueClass: 'ta-value error' },
            { label: 'Total TA Bike', value: this.totalLimitBikeKM, valueClass: 'ta-value success' },
            { label: 'Submitted TA Bike', value: this.submittedLimitBikeKM, valueClass: 'ta-value success' },
            { label: 'Approved TA Bike', value: this.approvedLimitBikeKM, valueClass: 'ta-value success' }
        ];
    }

    // ---------- HELPERS ----------
    processRow(row) {
        let editable = false;
        let selectable = false;

        const status = row.status;
        const type = row.expType;

        const l1 = this.expenseApprovers.L1;
        const finance = this.expenseApprovers.Finance;
        const user = this.currentUserId;

        if (user === l1 && status === 'Pending') {
            if (type !== 'TA') editable = true;
            selectable = true;
        } else if ((user === finance && status === 'Level 1 Approved') || (!l1 && user === finance && status === 'Pending')) {
            editable = true;
            selectable = true;
        } else if (this.isOpenedByAdmin && (status === 'Pending' || status === 'Level 1 Approved')) {
            if (type !== 'TA') editable = true;
            selectable = true;
        }

        // format date (YYYY-MM-DD -> DD-MM-YYYY)
        const dateStr = row.expDate;
        let dateStrIndia = '';
        if (dateStr) {
            const parts = dateStr.split('-');
            if (parts.length === 3) dateStrIndia = `${parts[2]}-${parts[1]}-${parts[0]}`;
        }

        // attachments
        let filesArray = [];
        if (row.files && row.files.length > 0) {
            filesArray = row.files.map((f) => {
                let downloadUrl;
                if (f.fileType === 'PDF') {
                    downloadUrl = `/sfc/servlet.shepherd/version/download/${f.latestVersionId}`;
                } else {
                    downloadUrl = `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${f.latestVersionId}`;
                }
                return {
                    id: f.contentDocumentId,
                    title: f.title,
                    downloadUrl,
                    isPdf: f.fileType === 'PDF'
                };
            });
        }

        return {
            ...row,
            expDate: dateStr,
            expDateFormatted: dateStrIndia,
            isEditable: editable,
            isSelectable: selectable,
            isChecked: false,
            files: filesArray,
            highlightClass: selectable ? 'highlight-row' : ''
        };
    }

    // ---------- UI ACTIONS ----------
    handleRefresh() {
        this.isspinner = true;
        Promise.all([
            refreshApex(this.wiredExpenseResult),
            refreshApex(this.wiredDataResult)
        ]).catch((error) => {
             this.isspinner = false;
            // eslint-disable-next-line no-console
            console.error('Error refreshing data:', error);
        });
        this.isspinner = false;
    }

    handleSelectAll(event) {
        const isChecked = event.target.checked;
        this.isAllSelected = isChecked;

        this.data = this.data.map((row) =>
            row.isSelectable ? { ...row, isChecked } : row
        );

        this.selectedRows = isChecked
            ? this.data.filter((r) => r.isSelectable).map((r) => r.recordId)
            : [];
    }

    handleRowSelection(event) {
        const recId = event.target.dataset.id;
        const checked = event.target.checked;

        this.data = this.data.map((row) =>
            row.recordId === recId ? { ...row, isChecked: checked } : row
        );

        this.selectedRows = checked
            ? Array.from(new Set([...this.selectedRows, recId]))
            : this.selectedRows.filter((id) => id !== recId);

        // keep select-all checkbox accurate
        const selectableCount = this.data.filter((r) => r.isSelectable).length;
        const selectedCount = this.selectedRows.length;
        this.isAllSelected = selectableCount > 0 && selectableCount === selectedCount;
    }

    handleAmountChange(event) {
        const recId = event.target.dataset.id;
        const newValue = Number(event.target.value);
        if (!Number.isFinite(newValue)) return;

        // update row (reactive)
        this.data = this.data.map((row) =>
            row.recordId === recId ? { ...row, amount: newValue } : row
        );

        // update drafts (reactive)
        const idx = this.draftValues.findIndex((d) => d.recordId === recId);
        if (idx >= 0) {
            this.draftValues = this.draftValues.map((d) =>
                d.recordId === recId ? { ...d, amount: newValue } : d
            );
        } else {
            this.draftValues = [...this.draftValues, { recordId: recId, amount: newValue }];
        }

        this.showSaveButton = this.draftValues.length > 0;
    }

    handleSave() {
        try{
        if (!this.draftValues.length) return;

        const updatedExpenses = this.draftValues.map((d) => ({
            Id: d.recordId,
            Amount__c: d.amount
        }));

        updateExpenseLineItems({ updatedExpenses })
            .then(() => {
                this.showToast('Success', 'Expenses updated successfully.', 'success');
                this.draftValues = [];
                this.showSaveButton = false;
                this.isAllSelected = false;

                return Promise.all([
                    refreshApex(this.wiredExpenseResult),
                    refreshApex(this.wiredDataResult)
                ]);
            })
            .catch((error) => {
                let message = 'Unknown error';

        if (error?.body?.message) {
            message = error.body.message;
        } else if (error?.message) {
            message = error.message;
        }
                this.showToast('Error',message, 'error');
                console.error('Save error'+JSON.stringify(error));
                alert('gg');
               
            });
        }catch(e){
            console.error(error.message);
        }

    }
 hadleExpenseCommentsChange(event)
    {
        const value = event.target.value;
        this.approvalComments = value;
    }
    handleExpenseCommentsChange(event) {
        this.approvalComments = event.target.value;
    }

    handleApprove() {
        if (this.selectedRows.length === 0) {
            this.showToast('No rows selected', 'Please select at least one row to approve.', 'warning');
            return;
        }

        approveExpenseItems({
            expenseIds: this.selectedRows,
            expId: this.recordId,
            approvalComments: this.approvalComments
        })
            .then(() => {
                this.showToast('Success', 'Selected expenses approved successfully.', 'success');
                this.selectedRows = [];
                this.approvalComments = '';
                this.isAllSelected = false;

                return Promise.all([
                    refreshApex(this.wiredExpenseResult),
                    refreshApex(this.wiredDataResult)
                ]);
            })
            .catch((err) => {
                this.showToast('Error', err.body?.message || err.message, 'error');
            });
    }

    async handleReject() {
        if (this.selectedRows.length === 0) {
            this.showToast('No rows selected', 'Please select at least one row to reject.', 'warning');
            return;
        }

        try {
            await rejectExpenses({
                expenseIds: this.selectedRows,
                expId: this.recordId,
                approvalComments: this.approvalComments
            });

            this.showToast('Success', 'Selected expenses rejected successfully.', 'success');
            this.selectedRows = [];
            this.approvalComments = '';
            this.isAllSelected = false;

            await Promise.all([
                refreshApex(this.wiredExpenseResult),
                refreshApex(this.wiredDataResult)
            ]);
        } catch (err) {
            this.showToast('Error', err.body?.message || err.message, 'error');
            console.error(JSON.stringify(err));
        }
    }

    previewFile(event) {
        if (!navigator.onLine) {
            this.showToast('Error', 'No internet connection. Please check your network and try again.', 'error');
            return;
        }

        const contentDocumentId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: contentDocumentId }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}