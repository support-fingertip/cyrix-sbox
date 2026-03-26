({
    doInit: function(component, event, helper) {
        helper.loadDocumentStatus(component);
    },

    handleUploadFinished: function(component, event, helper) {
        var selectedDocType = component.get("v.selectedDocType");
        if (!selectedDocType) {
            helper.showToast("Error", "Please select a document type before uploading.", "error");
            return;
        }

        component.set("v.isLoading", true);

        // Step 1: Rename file with doc type + date
        helper.callServer(component, "c.renameUploadedFile", {
            opportunityId: component.get("v.recordId"),
            documentType: selectedDocType
        }, function() {
            // Step 2: Check the respective checkbox
            helper.callServer(component, "c.handleDocumentUpload", {
                opportunityId: component.get("v.recordId"),
                documentType: selectedDocType
            }, function() {
                // Step 3: Refresh status
                helper.loadDocumentStatus(component);
                component.set("v.isLoading", false);
                helper.showToast("Success", selectedDocType + " document uploaded successfully.", "success");
            }, function(error) {
                component.set("v.isLoading", false);
                helper.showToast("Error", "Failed to update checkbox.", "error");
            });
        }, function(error) {
            component.set("v.isLoading", false);
            helper.showToast("Error", "Failed to rename file.", "error");
        });
    }
})
