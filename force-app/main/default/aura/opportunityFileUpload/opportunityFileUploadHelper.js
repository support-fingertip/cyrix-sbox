({
    DOC_TYPES: ["WO", "PO", "Cheque", "DD", "Cash", "UPI"],

    loadDocumentStatus: function(component) {
        var self = this;
        this.callServer(component, "c.getDocumentStatus", {
            opportunityId: component.get("v.recordId")
        }, function(result) {
            var statusList = self.DOC_TYPES.map(function(type) {
                return {
                    type: type,
                    uploaded: result[type] || false
                };
            });
            component.set("v.docStatusList", statusList);
        }, function(error) {
            console.error("Error loading document status:", error);
        });
    },

    callServer: function(component, actionName, params, successCallback, errorCallback) {
        var action = component.get(actionName);
        action.setParams(params);
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                if (successCallback) {
                    successCallback(response.getReturnValue());
                }
            } else {
                var errors = response.getError();
                var errorMsg = "Unknown error";
                if (errors && errors[0] && errors[0].message) {
                    errorMsg = errors[0].message;
                }
                console.error(actionName + " failed:", errorMsg);
                if (errorCallback) {
                    errorCallback(errorMsg);
                }
            }
        });
        $A.enqueueAction(action);
    },

    showToast: function(title, message, type) {
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            title: title,
            message: message,
            type: type
        });
        toastEvent.fire();
    }
})
