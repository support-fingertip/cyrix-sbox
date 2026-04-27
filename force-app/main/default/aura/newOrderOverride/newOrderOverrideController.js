({
    doInit : function(component, event, helper) {
        // Navigate to the "New Order" Lightning Component Tab (hosts newOrderCmp)
        // instead of opening the builder inside a modal. Works for both the
        // New button (recordId is the parent Account/Opportunity) and the
        // Edit button (recordId is the Order itself — newOrderCmp detects
        // the 801 prefix and switches to edit mode). Kick navigation off
        // first, then dismiss the launcher modal — closing it destroys
        // this Aura, so if we close before navService.navigate the
        // navigation gets canceled. Without the dismiss the launcher's
        // spinner stays stuck on top of the page and re-appears when the
        // user navigates back from the tab.
        var navService = component.find("navService");
        var pageRef = {
            type: "standard__navItemPage",
            attributes: {
                apiName: "Order"
            },
            state: {
                c__recordId: component.get("v.recordId")
            }
        };
        navService.navigate(pageRef);

        // Defer the close by one tick so navigation has actually been
        // dispatched before this Aura gets torn down — closing in the
        // same call stack as navigate() can cancel the navigation on
        // some devices.
        window.setTimeout($A.getCallback(function () {
            var dismiss = $A.get("e.force:closeQuickAction");
            if (dismiss) { dismiss.fire(); }
        }), 0);
    },

    closeModal : function(component, event, helper) {
        var overlayLib = component.find("overlayLib");
        if (overlayLib) {
            overlayLib.closeCustomModal();
        }
    }
})