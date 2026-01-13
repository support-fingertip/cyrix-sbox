({
    doInit : function(component, event, helper) {
        var recordId =component.get('v.recordId');
        if(recordId){
             var action = component.get("c.fetchLead");
              action.setParams({ leadId : recordId });
            action.setCallback(this,function(response){
            if(response.getState() == 'SUCCESS' ) { 
                 
               let lead = response.getReturnValue();
                    if(lead.Region__c){
                          component.set('v.regionName',lead.Region__r.Name);
                        if(lead.Region__r.Manager__c){
                            component.set('v.manager',lead.Region__r.Manager__c);
                            component.set('v.selectedAsmUser',lead.Region__r.Manager__c);
                        }
                    }else{
                       /* helper.showToast("Error",'Please choose region on  for this lead', "error");
                        var navEvt = $A.get("e.force:navigateToSObject");
                        navEvt.setParams({
                            recordId: component.get('v.recordId'),
                            slideDevName: "detail"
                        });
                        navEvt.fire();*/
                    }  
            }else{ 
                var errors = response.getError();
                console.error(JSON.stringify(errors));
                var errorMessage = "An Error occured"; // Default error message
                if (errors && errors[0] && errors[0].message) {
                    errorMessage = errors[0].message;
                }
                // Call function to show error in Toast
                helper.showToast("Error", errorMessage, "error");
                // $A.get('e.force:refreshView').fire();
            }
        });
            $A.enqueueAction(action);  
        }
        
    },
    doSubmit: function(component, event, helper) {

        var manager =component.get("v.selectedAsmUser");
        if(manager){
         var recordId =component.get('v.recordId');
         var action = component.get("c.ASMassignment");
              action.setParams({ 
                  owner : manager,
                   leadId : recordId });
            action.setCallback(this,function(response){
            if(response.getState() == 'SUCCESS' ) {  
                var lead = response.getReturnValue();
                        helper.showToast("Success",lead.Lead_Owner_Name__c+' now owns the record for '+lead.Name+'.', "success");
                        var navEvt = $A.get("e.force:navigateToSObject");
                        navEvt.setParams({
                            recordId: component.get('v.recordId'),
                            slideDevName: "detail"
                        });
                        navEvt.fire();
            }else{ 
                var errors = response.getError();
                console.error(JSON.stringify(errors));
                var errorMessage = "An Error occured"; // Default error message
                if (errors && errors[0] && errors[0].message) {
                    errorMessage = errors[0].message;
                }
                // Call function to show error in Toast
                helper.showToast("Error", errorMessage, "error");
                // $A.get('e.force:refreshView').fire();
            }
        });
            $A.enqueueAction(action); 
        }else{
            helper.showToast("Error", 'Please select the user', "error"); 
        }
    },
    closeModal: function(component, event, helper) {
             var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            recordId: component.get('v.recordId'),
            slideDevName: "detail"
        });
        navEvt.fire();
    },
    changeOption: function(component, event, helper) {
        
    },
})