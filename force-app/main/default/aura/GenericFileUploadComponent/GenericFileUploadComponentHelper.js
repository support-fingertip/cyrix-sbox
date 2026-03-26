({
    loadFiles: function(component) {
        var self = this;
        var documentType = component.get("v.documentType");
        this.callServer(component, "c.getFilesForDocType", {
            opportunityId: component.get("v.recordId"),
            documentType: documentType
        }, function(result) {
            component.set("v.files", result || []);
        }, function(error) {
            console.error("Error loading files:", error);
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
