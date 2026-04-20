({
    doInit : function(component, event, helper) {
        // Navigate to the "New Order" Lightning Component Tab (hosts newOrderCmp)
        // instead of opening the builder inside a modal. Works for both the
        // New button (recordId is the parent Account/Opportunity) and the
        // Edit button (recordId is the Order itself — newOrderCmp detects
        // the 801 prefix and switches to edit mode).
        var navService = component.find("navService");
        var pageRef = {
            type: "standard__navItemPage",
            attributes: {
                apiName: "New_Order"
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
