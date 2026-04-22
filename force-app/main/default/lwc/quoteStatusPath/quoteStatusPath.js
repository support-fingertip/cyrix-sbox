import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue, updateRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import QUOTE_OBJECT from '@salesforce/schema/Quote';
import STATUS_FIELD from '@salesforce/schema/Quote.Status';
import ID_FIELD from '@salesforce/schema/Quote.Id';
import REVISION_REASON_FIELD from '@salesforce/schema/Quote.Reason_for_Revision__c';

const REVISION_STATUS = 'Revision';
const LOCKED_STATUSES = new Set(['Approved', 'Rejected']);

export default class QuoteStatusPath extends LightningElement {
    @api recordId;

    @track picklistValues = [];
    currentStatus = '';
    selectedStatus = '';
    revisionReason = '';
    currentRevisionReason = '';
    isSaving = false;
    _defaultRecordTypeId;

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, REVISION_REASON_FIELD] })
    wiredRecord({ data, error }) {
        if (data) {
            this.currentStatus = getFieldValue(data, STATUS_FIELD) || '';
            this.currentRevisionReason = getFieldValue(data, REVISION_REASON_FIELD) || '';
            if (!this.selectedStatus) {
                this.selectedStatus = this.currentStatus;
            }
            if (this.selectedStatus !== REVISION_STATUS) {
                this.revisionReason = this.currentRevisionReason;
            }
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    @wire(getObjectInfo, { objectApiName: QUOTE_OBJECT })
    wiredObjectInfo({ data }) {
        if (data) {
            this._defaultRecordTypeId = data.defaultRecordTypeId;
        }
    }

    @wire(getPicklistValues, { recordTypeId: '$_defaultRecordTypeId', fieldApiName: STATUS_FIELD })
    wiredPicklist({ data, error }) {
        if (data) {
            this.picklistValues = (data.values || []).map(v => ({
                label: v.label,
                value: v.value
            }));
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    get isLoading() {
        return !this.picklistValues.length || !this.currentStatus;
    }

    get pathSteps() {
        const currentIdx = this.picklistValues.findIndex(p => p.value === this.currentStatus);
        return this.picklistValues.map((p, idx) => {
            const isLocked = LOCKED_STATUSES.has(p.value);
            const isCompleted = currentIdx >= 0 && idx < currentIdx;
            const isCurrent = p.value === this.currentStatus;
            const isSelected = p.value === this.selectedStatus && !isCurrent;
            let stepClass = 'qsp-step';
            if (isCompleted) stepClass += ' qsp-step-completed';
            if (isCurrent) stepClass += ' qsp-step-current';
            if (isSelected) stepClass += ' qsp-step-selected';
            if (isLocked && !isCurrent) stepClass += ' qsp-step-locked';
            const stepTitle = isLocked && !isCurrent
                ? `${p.value} is set by the approval process and cannot be marked manually.`
                : p.value;
            return {
                ...p,
                stepClass,
                isCompleted,
                isCurrent,
                isSelected,
                isLocked,
                stepTitle
            };
        });
    }

    get canMark() {
        return this.selectedStatus &&
            this.selectedStatus !== this.currentStatus &&
            !LOCKED_STATUSES.has(this.selectedStatus);
    }

    get showRevisionReason() {
        return this.selectedStatus === REVISION_STATUS && this.selectedStatus !== this.currentStatus;
    }

    get markButtonLabel() {
        if (this.isSaving) return 'Saving...';
        if (this.selectedStatus && this.selectedStatus !== this.currentStatus) {
            return `Mark as ${this.selectedStatus}`;
        }
        return 'Mark as Current';
    }

    handleStepClick(event) {
        const value = event.currentTarget.dataset.value;
        if (!value || this.isSaving) return;
        if (LOCKED_STATUSES.has(value) && value !== this.currentStatus) {
            this.showToast(
                'Not allowed',
                `${value} is set by the approval process and cannot be marked manually.`,
                'warning'
            );
            return;
        }
        this.selectedStatus = value;
        if (value === REVISION_STATUS) {
            this.revisionReason = '';
        }
    }

    handleRevisionReasonChange(event) {
        this.revisionReason = event.target.value;
    }

    async handleMarkStatus() {
        if (!this.canMark || this.isSaving) return;

        if (LOCKED_STATUSES.has(this.selectedStatus)) {
            this.showToast(
                'Not allowed',
                `${this.selectedStatus} can only be set by the approval process.`,
                'warning'
            );
            return;
        }

        if (this.selectedStatus === REVISION_STATUS) {
            const textarea = this.template.querySelector('lightning-textarea');
            const reason = (this.revisionReason || '').trim();
            if (!reason) {
                if (textarea) textarea.reportValidity();
                this.showToast(
                    'Reason required',
                    'Please enter a reason before marking the quote as Revision.',
                    'warning'
                );
                return;
            }
        }

        this.isSaving = true;

        const fields = {};
        fields[ID_FIELD.fieldApiName] = this.recordId;
        fields[STATUS_FIELD.fieldApiName] = this.selectedStatus;
        if (this.selectedStatus === REVISION_STATUS) {
            fields[REVISION_REASON_FIELD.fieldApiName] = this.revisionReason.trim();
        }

        try {
            await updateRecord({ fields });
            this.currentStatus = this.selectedStatus;
            if (this.selectedStatus === REVISION_STATUS) {
                this.currentRevisionReason = this.revisionReason.trim();
            }
            getRecordNotifyChange([{ recordId: this.recordId }]);
            this.showToast('Status Updated', `Quote marked as ${this.selectedStatus}.`, 'success');
        } catch (error) {
            this.selectedStatus = this.currentStatus;
            this.showToast('Update Failed', this.reduceError(error), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (!error) return 'Unknown error';
        if (typeof error === 'string') return error;
        if (error.body?.message) return error.body.message;
        if (error.body?.output?.errors?.length) {
            return error.body.output.errors.map(e => e.message).join(', ');
        }
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
}