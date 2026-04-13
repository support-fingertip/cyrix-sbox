({
    doInit : function(component, event, helper) {
        var recordId = component.get("v.recordId");
        var overlayLib = component.find("overlayLib");
        
        // Dynamically create the LWC component
        $A.createComponent(
            "c:newQuoteCmp",
            {
                "recordId": recordId,
                // Optional: pass a close callback
                "onclosepopup": component.getReference("c.closeModal")
            },
            function(newCmp, status, errorMsg) {
                if (status === "SUCCESS") {
                    // Show full-screen modal
                    overlayLib.showCustomModal({
                        header: "Quote Builder",
                        body: newCmp,
                        showCloseButton: true,
                        cssClass: "slds-modal_full",  // 👈 Full screen
                        closeCallback: function() {
                            // Optional: cleanup or refresh parent
                            console.log("Modal closed");
                        }
                    });
                } else {
                    console.error("Failed to create component: " + errorMsg);
                }
            }
        );
    },
    
    closeModal : function(component, event, helper) {
        var overlayLib = component.find("overlayLib");
        overlayLib.closeCustomModal();  // Close the modal if needed
    }
})