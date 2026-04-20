({
    doInit : function(component, event, helper) {
        var recordId = component.get("v.recordId");
        var url = "/lightning/n/Edit_Order?c__recordId=" + recordId;
        window.location.replace(url);
    }
})