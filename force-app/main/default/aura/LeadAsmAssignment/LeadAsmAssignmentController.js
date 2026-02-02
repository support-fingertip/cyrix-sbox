({
    doInit : function(component, event, helper) {
        try{
            var recordId =component.get('v.recordId');
            if(recordId){
                var action = component.get("c.fetchLead");
                action.setParams({ leadId : recordId });
                action.setCallback(this,function(response){
                    if(response.getState() == 'SUCCESS' ) { 
                        
                        let result = response.getReturnValue();
                        if(result!=null){
                            
                            let subRegionOptions=[];
                            subRegionOptions.push({label:'none',value:''});
                            component.set('v.regionRecord',result.region);
                            if( result.subRegions!=null){
                                component.set('v.subRegionRecords',result.subRegions);
                                result.subRegions.forEach(element => {
                                    subRegionOptions.push({label:element.Name,value:element.Id});
                            });
                        }
                        component.set('v.subRegionOptions',subRegionOptions);
                        
                        
                    }else{
                        helper.showToast("Error",'Please choose region  for this lead', "error");
                        var navEvt = $A.get("e.force:navigateToSObject");
                        navEvt.setParams({
                            recordId: component.get('v.recordId'),
                            slideDevName: "detail"
                        });
                        navEvt.fire();
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
}
 catch(e){
    console.error(e.message);
}

},
    doSubmit: function(component, event, helper) {
        try{
  var leadOwner =component.get("v.leadOwner");
        if(leadOwner){
              
            var recordId =component.get('v.recordId');
            var action = component.get("c.leadAssignment");
            action.setParams({ 
                 leadOwnerId: leadOwner, 
            leadId: component.get('v.recordId')
            });
            action.setCallback(this,function(response){
             
                if(response.getState() == 'SUCCESS' ) {   
                    helper.showToast("Success",'Lead Transferred successfully.', "success");
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
        }catch(e){
            console.error(e.message);
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
                  let leadOwner='';
               let optionSelected = component.get('v.optionSelected');
                    let subRegions = component.get('v.subRegionRecord');
                if(optionSelected=='ASM Transfer'){
                    if(subRegions.ASM__c){
                                leadOwner = subRegions.ASM__c ;
                    }
                      component.set('v.leadOwner',leadOwner); 
                            }else if(optionSelected=='Sales Exe Transfer'){
                                if(subRegions.Sales_Engineer__c){
                                    leadOwner = subRegions.Sales_Engineer__c ;
                                  component.set('v.leadOwner',leadOwner); 
                                }
                            
                            }else{
                   component.set('v.leadOwner',leadOwner); 
                            }
              
            },
                
                Mapsubregion: function(component, event, helper) {
                  
                    let leadOwner='';
                    let subRegionVal = component.get('v.subRegionVal');
                       let subRegions = component.get('v.subRegionRecords');
                     let optionSelected = component.get('v.optionSelected');
                    if(subRegionVal){
                         const selectedReg = subRegions.find(sub => sub.Id === subRegionVal);
                        if(selectedReg){
                          component.set('v.subRegionRecord',selectedReg); 
                            if(optionSelected=='ASM Transfer'){
                                if(selectedReg.ASM__c)
                                leadOwner = selectedReg.ASM__c ;
                                 component.set('v.leadOwner',leadOwner); 
                         
                            }else if(optionSelected=='Sales Exe Transfer'){
                                 if(selectedReg.Sales_Engineer__c)
                                    leadOwner = selectedReg.Sales_Engineer__c ;
                                 component.set('v.leadOwner',leadOwner); 
                         
                            }
                        }
                    }else{
                        component.set('v.subRegionRecord',null);  
                     component.set('v.optionSelected','');  
                        component.set('v.leadOwner',leadOwner); 
                    }
               
                 
              
                }

})