public with sharing class QuoteActionPanelController {

    /**
     * Submit a Quote into its active approval process with the rep's
     * comments. Throws AuraHandledException with the platform error
     * message if no active process is wired up — the LWC surfaces
     * that as a toast so the rep knows it's a config issue, not a
     * permissions one.
     */
    @AuraEnabled
    public static void submitForApproval(Id quoteId, String comments) {
        if (quoteId == null) {
            throw new AuraHandledException('Missing Quote id.');
        }

        try {
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(quoteId);
            // Comments are optional — pass through whatever the rep
            // typed (empty string is fine; the Approval framework
            // accepts a blank comment).
            if (String.isNotBlank(comments)) {
                req.setComments(comments);
            }
            req.setSubmitterId(UserInfo.getUserId());
            Approval.ProcessResult result = Approval.process(req);
            if (!result.isSuccess()) {
                String firstErr = result.getErrors() != null && !result.getErrors().isEmpty()
                    ? result.getErrors()[0].getMessage()
                    : 'Approval request was not accepted.';
                throw new AuraHandledException(firstErr);
            }
        } catch (AuraHandledException ae) {
            throw ae;
        } catch (Exception e) {
            // Most common: NO_APPLICABLE_PROCESS when no approval
            // process matches, or ALREADY_IN_APPROVAL_PROCESS when
            // the rep clicks twice.
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Active picklist values for Quote.Status (label + apiName). Done
     * via Schema describe so admins can edit the picklist without
     * code redeploys. Inactive values are skipped.
     */
    @AuraEnabled(cacheable=true)
    public static List<StatusOption> getQuoteStatusOptions(Id quoteId) {
        // quoteId is unused today but kept on the signature for
        // future record-type-aware filtering.
        List<StatusOption> options = new List<StatusOption>();
        Schema.DescribeFieldResult dfr = Quote.Status.getDescribe();
        for (Schema.PicklistEntry e : dfr.getPicklistValues()) {
            if (!e.isActive()) continue;
            StatusOption o = new StatusOption();
            o.label = e.getLabel();
            o.value = e.getValue();
            options.add(o);
        }
        return options;
    }

    /**
     * Update Quote.Status. When the new status is "Revision" (or the
     * caller passes a non-blank reason) the Reason_for_Revision__c
     * field is written too — that's the back-end half of the
     * "Reason for revision" popup that opens when the rep picks
     * Revision from the status list.
     */
    @AuraEnabled
    public static void updateStatus(Id quoteId, String newStatus, String reason) {
        if (quoteId == null) {
            throw new AuraHandledException('Missing Quote id.');
        }
        if (String.isBlank(newStatus)) {
            throw new AuraHandledException('Choose a status before saving.');
        }
        try {
            Quote q = new Quote(Id = quoteId, Status = newStatus);
            if (String.isNotBlank(reason)) {
                q.Reason_for_Revision__c = reason;
            }
            update q;
        } catch (DmlException de) {
            // Surface the first DML message so validation rules show
            // up cleanly in the toast (e.g. the
            // Require_Approval_Before_Approved rule that already
            // exists on this object).
            throw new AuraHandledException(de.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public class StatusOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }
}