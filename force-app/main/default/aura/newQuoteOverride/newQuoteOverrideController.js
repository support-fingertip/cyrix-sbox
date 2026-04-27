({
    doInit : function(component, event, helper) {
        // Navigate to the "New Quote" Lightning Component Tab (hosts newQuoteCmp)
        // instead of opening the builder inside a modal. Kick navigation off
        // first, then dismiss the quick-action launcher — the order matters
        // because closing the modal destroys this Aura, and if we close
        // before navService.navigate the navigation gets canceled. Without
        // the dismiss the launcher's spinner stays stuck on top of the page
        // and re-appears when the user navigates back.
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