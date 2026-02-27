({
 showToast: function(title,msg,type){
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": msg,
            "type":type
        });
        toastEvent.fire(); 
    },
    handleFetchObj : function(component, event, helper) {
         var action = component.get("c.getObjectAndCurrentUser");
         action.setParams({ 'recordId' : component.get('v.recordId') });
        action.setCallback(this,function(response){
            if(response.getState() == 'SUCCESS' ) { 
                var result = response.getReturnValue();
               component.set('v.objectName',result.objectName);
               component.set('v.profileName',result.profileName);
            }else{ 
                var errorMsg = JSON.stringify(response.getError());
                console.error(errorMsg);
            }
            
        });
        $A.enqueueAction(action); 
    }
})