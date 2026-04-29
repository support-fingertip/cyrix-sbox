public with sharing class quoteTriggerHandler {

    // Prevents recursion when the sibling-deactivation DML re-fires the after update trigger.
    private static Boolean isSyncingActiveQuote = false;

    // Set by the trigger so generateQuoteNames and other before-insert defaults
    // skip records that were inserted by our snapshot-clone logic.
    public static Boolean bypassInsertDefaults = false;

    // Quote Ids queued by before-update when the user flips Status to 'Revision'.
    // Processed in after-update to insert historical snapshots with their children.
    public static Set<Id> quotesPendingSnapshot = new Set<Id>();

    private static Boolean isSnapshotInProgress = false;

    /**
     * Auto-populates L1/L2/L3 Approver fields on the Quote based on the
     * Owner's Manager hierarchy.
     *   L1 = Owner.Manager                 (e.g. ASM)
     *   L2 = Owner.Manager.Manager         (e.g. TSM)
     *   L3 = Owner.Manager.Manager.Manager (e.g. Order Acceptance / Finance)
     *
     * Only fills fields that are currently null, so manual overrides on a
     * Quote are preserved.
     */
    public static void populateApproversFromHierarchy(List<Quote> quotes) {
        
        if (quotes == null || quotes.isEmpty()) return;
       list< General_Settings__c> settingsList =[select Id, Order_Acceptance_Approver__c from General_Settings__c limit 1];  

        Set<Id> ownerIds = new Set<Id>();
        for (Quote q : quotes) {
            if (q.OwnerId != null) ownerIds.add(q.OwnerId);
        }
        if (ownerIds.isEmpty()) return;

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, ManagerId,
                   Manager.ManagerId
            FROM User
            WHERE Id IN :ownerIds
        ]);

        for (Quote q : quotes) {
            User owner = userMap.get(q.OwnerId);
            if (owner == null) continue;

            if (q.L1_Approver__c == null && owner.ManagerId != null) {
                q.L1_Approver__c = owner.ManagerId;
            }
            if (q.L2_Approver__c == null && owner.Manager != null
                && owner.Manager.ManagerId != null) {
                q.L2_Approver__c = owner.Manager.ManagerId;
            }
            if (q.L3_Approver__c == null && !settingsList.isEmpty()) {
                q.L3_Approver__c = settingsList[0].Order_Acceptance_Approver__c;
            }
        }
    }

    /**
     * Notifies the Quote Owner when the Quote moves through the approval
     * lifecycle. Fires on every notify-worthy transition of either
     * Approval_Status__c (set by the multi-level standard approval flows)
     * or Price_Status__c (set by the custom approveLineItems action).
     *
     * Notify-worthy Approval_Status__c values:
     *   Level 1 Approved   - L1 manager signed off
     *   Level 2 Approved   - L2 manager signed off
     *   Approved           - Final approval completed (L3 / Order Acceptance)
     *   Rejected           - Any approver rejected the quote
     *
     * Notify-worthy Price_Status__c values:
     *   Approved   - Custom approveLineItems final approval
     *   Rejected   - Custom approveLineItems rejection
     *
     * Two paths are checked because the standard approval flow updates
     * Approval_Status__c reliably, while the custom flow drives
     * Price_Status__c — relying on either alone caused the owner to miss
     * notifications on legitimate transitions.
     */
    public static void notifyOwnerOnApproval(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        if (newQuotes == null || newQuotes.isEmpty() || oldMap == null) return;

        // Each entry pairs the quote with the new status value that
        // triggered the notification, so we can build a title + body
        // that reflects the actual stage (Level 1, Level 2, Approved,
        // Rejected) instead of a generic "approved" message.
        List<Quote> targets = new List<Quote>();
        List<String> targetStatuses = new List<String>();

        for (Quote q : newQuotes) {
            Quote oldQ = oldMap.get(q.Id);
            if (oldQ == null) continue;
            if (q.OwnerId == null) continue;

            String triggerStatus = pickNotifyStatus(q, oldQ);
            if (triggerStatus == null) continue;

            targets.add(q);
            targetStatuses.add(triggerStatus);
        }
        if (targets.isEmpty()) return;

        Id notifTypeId;
        try {
            notifTypeId = [
                SELECT Id
                FROM CustomNotificationType
                WHERE DeveloperName = 'Quote_Approval_Notification'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            System.debug('Quote_Approval_Notification type missing: ' + e.getMessage());
            return;
        }

        // Whoever clicked Approve/Reject in the standard approval process
        // (or the custom approveLineItems action) is the running user when
        // the workflow field updates re-fire this trigger.
        String approverName = UserInfo.getName();

        for (Integer i = 0; i < targets.size(); i++) {
            Quote q = targets[i];
            String status = targetStatuses[i];
            try {
                CustomNotificationService.notificationSend(
                    titleFor(status),
                    q.Id,
                    bodyFor(q, status, approverName),
                    new Set<String>{ String.valueOf(q.OwnerId) },
                    notifTypeId
                );
            } catch (Exception e) {
                System.debug('Quote approval notification error: ' + e.getMessage());
            }
        }
    }

    // Status values worth notifying on for each driver field. Anything
    // outside these sets (Pending, Submitted, etc.) intentionally stays
    // silent so we don't spam the owner mid-flow.
    private static final Set<String> APPROVAL_NOTIFY_STATUSES = new Set<String>{
        'Level 1 Approved', 'Level 2 Approved', 'Approved', 'Rejected'
    };
    private static final Set<String> PRICE_NOTIFY_STATUSES = new Set<String>{
        'Approved', 'Rejected'
    };

    private static String pickNotifyStatus(Quote q, Quote oldQ) {
        // Approval_Status__c takes precedence — it carries the level
        // detail (Level 1 / Level 2 / Approved / Rejected) that the
        // owner needs to see in the bell.
        String newAppr = q.Approval_Status__c;
        String oldAppr = oldQ.Approval_Status__c;
        if (newAppr != null
            && APPROVAL_NOTIFY_STATUSES.contains(newAppr)
            && newAppr != oldAppr) {
            return newAppr;
        }
        String newPrice = q.Price_Status__c;
        String oldPrice = oldQ.Price_Status__c;
        if (newPrice != null
            && PRICE_NOTIFY_STATUSES.contains(newPrice)
            && newPrice != oldPrice) {
            return newPrice;
        }
        return null;
    }

    private static String titleFor(String status) {
        if (status == 'Rejected') return 'Your Quote has been Rejected';
        return 'Your Quote has been Approved';
    }

    private static String bodyFor(Quote q, String status, String approverName) {
        // Approval_Status__c values are written verbatim for the level
        // detail; Price_Status__c only carries Approved / Rejected.
        if (status == 'Level 1 Approved') {
            return 'Your Quote ' + q.Name + ' has been approved at Level 1 by ' + approverName + '.';
        }
        if (status == 'Level 2 Approved') {
            return 'Your Quote ' + q.Name + ' has been approved at Level 2 by ' + approverName + '.';
        }
        if (status == 'Rejected') {
            return 'Your Quote ' + q.Name + ' has been rejected by ' + approverName + '.';
        }
        // 'Approved' (final or price-status driven)
        return 'Your Quote ' + q.Name + ' has been approved by ' + approverName + '.';
    }

    /**
     * BRD: only one active quote per Opportunity. When a sibling quote is
     * already active AND in the approval flow ('Approval Required' /
     * 'Approved'), it is locked by the approval process and cannot be
     * deactivated by Apex without the org-level approval lock/unlock
     * preference.
     *
     * Per the TL: in that case, do NOT touch the locked sibling. Instead,
     * force the incoming quote's is_Active__c to false so it is created /
     * saved as an inactive quote. The previously-active locked quote stays
     * active and the BRD is preserved (still only one active quote).
     *
     * Runs in before insert / before update so trigger.new can be mutated
     * without DML.
     */
    public static void enforceInactiveWhenSiblingLocked(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        if (newQuotes == null || newQuotes.isEmpty()) return;

        Set<Id> oppIds = new Set<Id>();
        List<Quote> candidates = new List<Quote>();
        for (Quote q : newQuotes) {
            if (q.OpportunityId == null || q.is_Active__c != true) continue;
            // For updates, only act when the quote is just being activated.
            if (oldMap != null) {
                Quote oldQ = oldMap.get(q.Id);
                if (oldQ != null && oldQ.is_Active__c == true) continue;
            }
            oppIds.add(q.OpportunityId);
            candidates.add(q);
        }
        if (candidates.isEmpty()) return;

        Set<Id> oppsWithLockedActive = new Set<Id>();
        for (Quote sibling : [
            SELECT Id, OpportunityId
            FROM Quote
            WHERE OpportunityId IN :oppIds
            AND is_Active__c = true
            AND Price_Status__c IN ('Approval Required', 'Approved')
        ]) {
            oppsWithLockedActive.add(sibling.OpportunityId);
        }
        if (oppsWithLockedActive.isEmpty()) return;

        for (Quote q : candidates) {
            if (oppsWithLockedActive.contains(q.OpportunityId)) {
                q.is_Active__c = false;
            }
        }
    }

    /**
     * When a Quote flips is_Active__c to true, mark every other quote on the
     * same Opportunity as inactive and sync the current quote to the
     * Opportunity (Opportunity.SyncedQuoteId -> this Quote). Salesforce then
     * sets Quote.IsSyncing = true automatically on the synced quote.
     *
     * Locked siblings (Price_Status__c IN 'Approval Required', 'Approved')
     * are skipped here because the incoming quote was already forced
     * inactive in before-insert / before-update by
     * enforceInactiveWhenSiblingLocked, so we never reach this method with a
     * locked sibling on the same opportunity.
     */
    public static void syncActiveQuote(List<Quote> newQuotes, Map<Id, Quote> oldMap) {
        if (isSyncingActiveQuote) return;

        Map<Id, Id> oppToActiveQuote = new Map<Id, Id>();
        for (Quote q : newQuotes) {
            if (q.OpportunityId == null || q.is_Active__c != true) continue;
            Boolean justActivated = (oldMap == null)
                || (oldMap.get(q.Id) != null && oldMap.get(q.Id).is_Active__c != true);
            if (justActivated) {
                // Last write wins if multiple quotes on the same opp are activated in one DML.
                oppToActiveQuote.put(q.OpportunityId, q.Id);
            }
        }
        if (oppToActiveQuote.isEmpty()) return;

        isSyncingActiveQuote = true;
        try {
            // Deactivate every other active quote on the impacted opportunities.
            List<Quote> siblings = [
                SELECT Id, OpportunityId, is_Active__c
                FROM Quote
                WHERE OpportunityId IN :oppToActiveQuote.keySet()
                AND Id NOT IN :oppToActiveQuote.values()
                AND is_Active__c = true
            ];
            if (!siblings.isEmpty()) {
                for (Quote s : siblings) s.is_Active__c = false;
                update siblings;
            }

            // Opportunity.SyncedQuoteId is read-only inside the triggering
            // transaction, so push the sync out to an async job.
            if (!System.isFuture() && !System.isBatch() && !System.isQueueable()) {
                syncOpportunityToQuoteFuture(
                    new List<Id>(oppToActiveQuote.keySet()),
                    new List<Id>(oppToActiveQuote.values())
                );
            }
        } finally {
            isSyncingActiveQuote = false;
        }
    }

    @future
    public static void syncOpportunityToQuoteFuture(List<Id> oppIds, List<Id> quoteIds) {
        if (oppIds == null || quoteIds == null || oppIds.size() != quoteIds.size()) return;
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < oppIds.size(); i++) {
            opps.add(new Opportunity(Id = oppIds[i], SyncedQuoteId = quoteIds[i]));
        }
        if (!opps.isEmpty()) update opps;
    }

    /**
     * Generates the auto quote name for a list of Quote records.
     * Called from before insert and before update triggers.
     */
    public static void generateQuoteNames(List<Quote> newQuotes) {
        // Collect branches and financial years for which we need to calculate next numbers
        Set<String> branchYearKeys = new Set<String>();
        set<string> branchIds = new set<string>();
        for (Quote q : newQuotes) {
            // Only process if Branch is populated and Quote Name is empty (or needs regeneration)
            if (q.Branch__c == null) continue;
            branchIds.add(q.Branch__c);
            // Determine if we need to generate a new name
            Boolean needsNewName = false;
            if (Trigger.isInsert) {
                needsNewName = true;
            }
        }

        if (branchIds.isEmpty()) return;

        // Query existing quotes to find the current maximum sequential number per branch/year
        Map<String, Quote_Number_Series__c> maxNumberMap = new Map<String, Quote_Number_Series__c>();
        map<Id,Quote_Number_Series__c> quoteSeriesMap = new    map<Id,Quote_Number_Series__c> ([SELECT Branch__c, Name, Last_Quote_Number__c,Short_Code__c
            FROM Quote_Number_Series__c
            WHERE Branch__c IN :branchIds
            AND isActive__c=true]);
        for (Quote_Number_Series__c ar :quoteSeriesMap.values()) {
           maxNumberMap.put(ar.Branch__c, ar);
        }

        // Assign sequential numbers and build names
        for (Quote q : newQuotes) {
            if (q.Branch__c == null) continue;

            // Determine if this quote needs a name

            if (Trigger.isInsert) {
                  String key = q.Branch__c ;
            decimal nextNumber = maxNumberMap.containsKey(key) ? ((maxNumberMap.get(key).Last_Quote_Number__c !=null?maxNumberMap.get(key).Last_Quote_Number__c:0) + 1) : 1;
            maxNumberMap.get(key).Last_Quote_Number__c=nextNumber; // increment for next quote in same batch
           string  shortCode =maxNumberMap.get(key).Short_Code__c ;
            // Store the sequential number and financial year on the quote (for future queries)
            string financialYear =  maxNumberMap.get(key).Name;


            // Build the name
            String baseName = 'QTN-' + String.valueOf(nextNumber.intValue()).leftPad(4, '0') + '/CHC/' + financialYear+'-'+q.Business_Vertical__c ;
            if (q.Version_Nmber__c != null && q.Version_Nmber__c >= 1) {
                baseName += '-RV' + q.Version_Nmber__c;
            }
            q.Name = baseName;
            }

        update maxNumberMap.values();


        }
    }

    /**
     * When a user flips Quote.Status to 'Revision', insert a locked historical
     * snapshot of the quote *before* the existing before-update logic renames
     * the record and increments its version. The snapshot carries clones of
     * every child record the sales team keeps on a quote: line items, payment
     * terms, notes, exclusions, and terms & conditions.
     *
     * Clone-inserted quotes skip the before-insert defaults (name generation,
     * version reset, valid-till stamping) via the bypassInsertDefaults flag.
     */
    public static void snapshotQuotesOnRevision(Map<Id, Quote> oldMap) {
        if (isSnapshotInProgress) return;
        if (quotesPendingSnapshot == null || quotesPendingSnapshot.isEmpty()) return;

        List<Id> originalIds = new List<Id>(quotesPendingSnapshot);
        quotesPendingSnapshot.clear();

        isSnapshotInProgress = true;
        try {
            // Build snapshot Quote records from the pre-update (oldMap) values so the
            // snapshot carries the original Name/Version/Status, not the post-rename values.
            List<Quote> snapshots = new List<Quote>();
            List<Id> orderedOrigIds = new List<Id>();
            for (Id origId : originalIds) {
                Quote oldQ = oldMap.get(origId);
                if (oldQ == null) continue;
                Quote snap = oldQ.clone(false, true, false, false);
                snap.is_Active__c = false;
                // Link the snapshot back to the quote record that now carries
                // the new revision, so users can navigate from history to current.
                snap.Revised_Quote__c = origId;
                snapshots.add(snap);
                orderedOrigIds.add(origId);
            }
            if (snapshots.isEmpty()) return;

            bypassInsertDefaults = true;
            insert snapshots;
            bypassInsertDefaults = false;

            Map<Id, Id> originalToSnapshot = new Map<Id, Id>();
            for (Integer i = 0; i < orderedOrigIds.size(); i++) {
                originalToSnapshot.put(orderedOrigIds[i], snapshots[i].Id);
            }

            // Clone QuoteLineItems
            List<QuoteLineItem> newQlis = new List<QuoteLineItem>();
            for (QuoteLineItem qli : [
                SELECT Id, QuoteId, Product2Id, PricebookEntryId, Quantity, UnitPrice,
                       Discount, Description, ServiceDate,
                       Source_Pricebook_Ref__c, Price_Status__c, Tax_Type__c,
                       Product_Line_Description__c, Product_Detailed_Description__c
                FROM QuoteLineItem
                WHERE QuoteId IN :orderedOrigIds
            ]) {
                QuoteLineItem n = new QuoteLineItem(
                    QuoteId = originalToSnapshot.get(qli.QuoteId),
                    Product2Id = qli.Product2Id,
                    PricebookEntryId = qli.PricebookEntryId,
                    Quantity = qli.Quantity,
                    UnitPrice = qli.UnitPrice,
                    Discount = qli.Discount,
                    Description = qli.Description,
                    ServiceDate = qli.ServiceDate,
                    Source_Pricebook_Ref__c = qli.Source_Pricebook_Ref__c,
                    Price_Status__c = qli.Price_Status__c,
                    Tax_Type__c = qli.Tax_Type__c,
                    Product_Line_Description__c = qli.Product_Line_Description__c,
                    Product_Detailed_Description__c = qli.Product_Detailed_Description__c
                );
                newQlis.add(n);
            }
            if (!newQlis.isEmpty()) insert newQlis;

            // Clone Payment_Term__c
            List<Payment_Term__c> newPts = new List<Payment_Term__c>();
            for (Payment_Term__c pt : [
                SELECT Id, Quote__c, Payment_Term__c, Percentage__c
                FROM Payment_Term__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Payment_Term__c n = pt.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(pt.Quote__c);
                newPts.add(n);
            }
            if (!newPts.isEmpty()) insert newPts;


            // Clone Exclusions__c
            List<Exclusions__c> newEx = new List<Exclusions__c>();
            for (Exclusions__c ex : [
                SELECT Id, Quote__c, Exclusions__c
                FROM Exclusions__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Exclusions__c n = ex.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(ex.Quote__c);
                newEx.add(n);
            }
            if (!newEx.isEmpty()) insert newEx;

            // Clone Terms_Condition__c
            List<Terms_Condition__c> newTcs = new List<Terms_Condition__c>();
            for (Terms_Condition__c tc : [
                SELECT Id, Quote__c, T_C__c, Titile__c
                FROM Terms_Condition__c
                WHERE Quote__c IN :orderedOrigIds
            ]) {
                Terms_Condition__c n = tc.clone(false, true, false, false);
                n.Quote__c = originalToSnapshot.get(tc.Quote__c);
                newTcs.add(n);
            }
            if (!newTcs.isEmpty()) insert newTcs;
        } finally {
            isSnapshotInProgress = false;
            bypassInsertDefaults = false;
        }
    }
}