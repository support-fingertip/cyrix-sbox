({
    doInit: function (component, event, helper) {
        // 1. Check if recordId is set (from force:hasRecordId - e.g., Opportunity page)
        var recordId = component.get("v.recordId");
        if (recordId) {
            component.set("v.opportunityId", recordId);
            return;
        }

        // 2. Check URL parameters (from lightning:isUrlAddressable)
        var pageRef = component.get("v.pageReference");
        if (pageRef && pageRef.state) {
            var oppId = pageRef.state.c__opportunityId || pageRef.state.c__recordId;
            if (oppId) {
                component.set("v.opportunityId", oppId);
                return;
            }
        }

        // 3. Check inContextOfRef (when launched from Opportunity related list "New Quote")
        var pageReference = component.get("v.pageReference");
        if (pageReference && pageReference.state && pageReference.state.inContextOfRef) {
            try {
                var context = JSON.parse(
                    window.atob(pageReference.state.inContextOfRef)
                );
                if (context && context.attributes && context.attributes.recordId) {
                    component.set("v.opportunityId", context.attributes.recordId);
                    return;
                }
            } catch (e) {
                console.warn("Could not parse inContextOfRef", e);
            }
        }

        // 4. Fallback: check standard URL parameters
        var urlParams = new URLSearchParams(window.location.search);
        var oppIdFromUrl = urlParams.get("oppId") || urlParams.get("opportunityId");
        if (oppIdFromUrl) {
            component.set("v.opportunityId", oppIdFromUrl);
            return;
        }

        // 5. If no Opportunity context found, show error and navigate back
        var toastEvent = $A.get("e.force:showToast");
        if (toastEvent) {
            toastEvent.setParams({
                title: "Error",
                message:
                    "Please create a new Quote from the Opportunity record page using the 'Create Quote' button.",
                type: "error",
            });
            toastEvent.fire();
        }

        // Navigate back
        var navEvent = $A.get("e.force:navigateToObjectHome");
        if (navEvent) {
            navEvent.setParams({ scope: "Quote" });
            navEvent.fire();
        }
    },
})
