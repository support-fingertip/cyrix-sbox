({
    doInit : function(component, event, helper) {
        var navService = component.find("navService");
        var pageRef = {
            type: "standard__navItemPage",
            attributes: {
                apiName: "Edit_Order"
            },
            state: {
                c__recordId: component.get("v.recordId")
            }
        };
        navService.navigate(pageRef);
    }
})
