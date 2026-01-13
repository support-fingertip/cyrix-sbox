({
    loadLeads : function(component, event, helper) {
        component.set('v.step',2);
        var action = component.get("c.fetchLeads");
        action.setParams({
            firstLeadId: component.get("v.recordId"),
            secondLeadId: component.get("v.selectedleadId")
        });
        
        action.setCallback(this, function(response) {
            if (response.getState() === "SUCCESS") {
                let result = response.getReturnValue();
                component.set("v.fields", result.fieldset);
                component.set("v.firstLead", result.firstLead);
                component.set("v.secondLead", result.secondLead);
            } else {
                helper.showToast("Error", "Failed to load leads", "error");
            }
        });
        $A.enqueueAction(action);
    },
    
    handleSelection : function(component, event, helper) {
          // Get the selected value and the field label
        let selectedMap = component.get("v.selectedFields");
        let fieldLabel = event.getSource().get("v.name");
        let choice = event.getSource().get("v.value");
        
        let fields = component.get("v.fields");
        let selectedField = fields.find(f => f.label === fieldLabel);
        
        if (choice === "lead1") {
            selectedMap[fieldLabel] = selectedField.value1;
        } else {
            selectedMap[fieldLabel] = selectedField.value2;
        }
        component.set("v.selectedFields", selectedMap);
    },
 handleClickSelectAll : function(component, event, helper) {
     try{
         // Get the lead type (lead1 or lead2)
         let selectedLead = event.getSource().get("v.title");
         let selectedMap = {}; 
         // Set all related radio buttons for lead1 to the same state
         let fields = component.get("v.fields");
         
    if (selectedLead === "lead1") {
        // Toggle the selection for all radio buttons related to lead1
        let selectAllLead1 = !component.get("v.selectAllLead1");
        component.get("v.selectAllLead2",false);
        component.set("v.selectAllLead1", selectAllLead1);
        fields.forEach(function(field) {
             selectedMap[field.label] = field.value1;
        });
  
    } else if (selectedLead === "lead2") {
        // Toggle the selection for all radio buttons related to lead2
        let selectAllLead2 = !component.get("v.selectAllLead2");
         component.get("v.selectAllLead1",false);
        component.set("v.selectAllLead2", selectAllLead2);
       fields.forEach(function(field) {
             selectedMap[field.label] = field.value2;
        });
    }   
       component.set("v.fields", fields); // Update fields to reflect changes        
     }catch(error){
         console.error(error.message);
     }    
    },
    doConfirm : function(component, event, helper) {
       component.set('v.step',3); 
    },
    
  domergeLeads : function(component, event, helper) {
        var action = component.get("c.mergeLeads");
        action.setParams({
            firstLead: component.get("v.firstLead"), // main record to keep
            secondLead: component.get("v.secondLead"), // record to merge
            selectedFields: component.get("v.selectedFields")
        });
        
        action.setCallback(this, function(response) {
            if (response.getState() === "SUCCESS") {
                helper.showToast("Success", "Leads merged successfully!", "success");
                
                var navEvt = $A.get("e.force:navigateToSObject");
                navEvt.setParams({
                    recordId: component.get('v.recordId'),
                    slideDevName: "detail"
                });
                navEvt.fire();
                
                
            } else {
                var errors = response.getError();
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
    },
    closeModal: function(component, event, helper) {
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
            recordId: component.get('v.recordId'),
            slideDevName: "detail"
        });
        navEvt.fire();
    },
    
})