({
     doInit : function(component,event,helper){
        component.set('v.showpopup',true);
             var device = $A.get("$Browser.formFactor");
         component.set('v.formFactor',device);
        if(device == 'DESKTOP'){
             var cmpTarget = component.find('model');
        $A.util.removeClass(cmpTarget, 'slds-modal_full');
        }
    },    
    handleSave : function(component, event, helper) {
        // Find form and submit
        var form = component.find("recordEditForm");
        if (form) {
            form.submit();
        }
    },

    handleSuccess : function(component, event, helper) {
        var payload = event.getParams().response;
         component.set('v.showpopup',false);
        // Navigate to new Campaign record
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            recordId: payload.id,
            slideDevName: "detail"
        });
        navEvt.fire();
    },

 handleError: function (component, event, helper) {
         component.set('v.disableSave',false); 
      // Extract error details from the event
        var errorDetails = event.getParam("error");
        console.error('Error Details:', JSON.stringify(errorDetails));
        
        let toastMessage = "An error occurred."; // Default error message
        let fieldErrors = errorDetails.body && errorDetails.body.output ? errorDetails.body.output.fieldErrors : '';
        
        
        // Check for field validation errors
        if (fieldErrors) {
            for (let field in fieldErrors) {
                if (fieldErrors[field] && fieldErrors[field].length > 0) {
                    // Use the first error message for the field
                    toastMessage = fieldErrors[field][0].message;
                    break; // Stop after the first error for simplicity
                }
            }
        } else {
            // Fallback to the main error message if fieldErrors are not present
            toastMessage = event.getParam("message");
        }
        
        // Display the toast message
        helper.showToast("Error", toastMessage, "error");
    },

      closeModal: function(component, event, helper) {
  component.set('v.showpopup',false);
            var homeEvt = $A.get("e.force:navigateToObjectHome");
            homeEvt.setParams({
                "scope": "Campaign"
            });
            homeEvt.fire();
    },
})