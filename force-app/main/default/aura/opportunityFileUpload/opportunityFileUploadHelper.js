({
    loadDocumentStatus: function(component) {
        var action = component.get("c.getDocumentStatus");
        action.setParams({
            opportunityId: component.get("v.recordId")
        });
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                component.set("v.docStatus", response.getReturnValue());
            } else {
                console.error("Error loading document status");
            }
        });
        $A.enqueueAction(action);
    }
})
