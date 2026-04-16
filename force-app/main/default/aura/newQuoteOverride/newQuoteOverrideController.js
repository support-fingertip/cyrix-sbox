({
    doInit : function(component, event, helper) {
        // Navigate to the "New Quote" Lightning Component Tab (hosts newQuoteCmp)
        // instead of opening the builder inside a modal.
        var navService = component.find("navService");
        var pageRef = {
            type: "standard__navItemPage",
            attributes: {
                apiName: "New_Quote"
            },
            state: {
                c__recordId: component.get("v.recordId")
            }
        };
        navService.navigate(pageRef);
    },

    closeModal : function(component, event, helper) {
        var overlayLib = component.find("overlayLib");
        if (overlayLib) {
            overlayLib.closeCustomModal();
        }
    }
})