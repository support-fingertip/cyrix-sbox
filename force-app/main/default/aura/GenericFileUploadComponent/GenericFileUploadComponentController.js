({
    doInit: function(component, event, helper) {
        helper.loadFiles(component);
    },

    handleUploadFinished: function(component, event, helper) {
        var documentType = component.get("v.documentType");
        var recordId = component.get("v.recordId");

        component.set("v.isLoading", true);

        // Step 1: Rename file with doc type + date
        helper.callServer(component, "c.renameUploadedFile", {
            opportunityId: recordId,
            documentType: documentType
        }, function() {
            // Step 2: Check the respective checkbox on Opportunity
            helper.callServer(component, "c.handleDocumentUpload", {
                opportunityId: recordId,
                documentType: documentType
            }, function() {
                component.set("v.isUploaded", true);
                component.set("v.isLoading", false);
                helper.loadFiles(component);
                helper.showToast("Success", documentType + " document uploaded successfully.", "success");

                // Fire event to notify parent
                var uploadEvent = component.getEvent("onFileUploaded");
                uploadEvent.setParams({ documentType: documentType });
                uploadEvent.fire();
            }, function(error) {
                component.set("v.isLoading", false);
                helper.showToast("Error", "Failed to update checkbox: " + error, "error");
            });
        }, function(error) {
            component.set("v.isLoading", false);
            helper.showToast("Error", "Failed to rename file: " + error, "error");
        });
    },

    previewFile: function(component, event, helper) {
        var fileId = event.currentTarget.dataset.id;
        $A.get("e.lightning:openFiles").fire({
            recordIds: [fileId]
        });
    },

    deleteFile: function(component, event, helper) {
        if (!confirm("Confirm deleting this file?")) return;

        var fileId = event.currentTarget.dataset.id;
        component.set("v.isLoading", true);

        helper.callServer(component, "c.deleteUploadedFile", {
            contentDocumentId: fileId
        }, function() {
            helper.loadFiles(component);
            component.set("v.isLoading", false);
            helper.showToast("Success", "File deleted successfully.", "success");
        }, function(error) {
            component.set("v.isLoading", false);
            helper.showToast("Error", "Failed to delete file.", "error");
        });
    }
})
