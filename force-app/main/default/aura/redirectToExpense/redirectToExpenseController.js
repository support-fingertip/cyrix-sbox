({
	doInit : function(component, event, helper) {
        component.set("v.openPopup", true);
	},
    onClickClosePopup: function(component, event, helper) {
      
        var getMessage = event.getParam('eventType');
        if(getMessage == 'Cancel'){
            var homeEvt = $A.get("e.force:navigateToObjectHome");
            homeEvt.setParams({
                "scope": "Expense__c"
            });
            homeEvt.fire();
            $A.get('e.force:refreshView').fire();
        }
        else if(getMessage == 'Done')
        {
            var dismissActionPanel = $A.get("e.force:closeQuickAction");
            dismissActionPanel.fire();
            var Id = event.getParam('Id');
            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                "recordId": Id,
                "slideDevName": "detail" 
            });
            navEvt.fire();
            
            $A.get('e.force:refreshView').fire();
            
        }
    },
    onPageReferenceChange: function(component, event, helper) {
        var detail = {};
        detail["isPullToRefreshEnabled"] = false;
        detail["isPullToShowMoreEnabled"] = false;
        var updateScrollSettingsEvent = new CustomEvent("updateScrollSettings", {
            detail: detail,
            bubbles: true,
            composed: true
        });
        dispatchEvent(updateScrollSettingsEvent);
        // Force refresh the page
        $A.get('e.force:refreshView').fire();
    }
})