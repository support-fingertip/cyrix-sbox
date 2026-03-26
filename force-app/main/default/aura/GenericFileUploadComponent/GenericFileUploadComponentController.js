({
    doInit : function(component, event, helper) {
        var recordId = component.get("v.recordId");
        console.log('recordId :'+recordId );
        
        let commaSeparatedValues = component.get('v.picklistValues');
        component.set("v.docStringList", commaSeparatedValues);

        // Convert to array and format for lightning:combobox
        let picklistOptions = commaSeparatedValues.split(',').map(value => {
            return { label: value.trim(), value: value.trim() };
        });
        
        picklistOptions.unshift({ label: "All", value: "" ,selected:true});
        
        // Set the formatted picklist values in component
        component.set("v.picklistValues", picklistOptions);
        
        var documentName = component.get("v.selectedDocumentName");
        console.log('documentName :'+documentName );
        
        if (recordId) {
            if (documentName && documentName !== '') {
                helper.fetchUploadedFiles(component, recordId, documentName);
            } else {
                helper.fetchUploadedFiles(component, recordId,'');
            }
        }
    },

    handleChange: function(component, event, helper) {
        let selectedValue = event.getParam("value");
        var recordId = component.get("v.recordId");
        console.log('selectedValue'+selectedValue);
        component.set("v.selectedDocumentName",selectedValue);
        if (recordId) {
            if (selectedValue && selectedValue !== '') {
                helper.fetchUploadedFiles(component, recordId, selectedValue);
            } else {
                helper.fetchUploadedFiles(component, recordId,'');
            }
        }
    },
    filesChangeHandler: function(component, event, helper){
        var files = component.find("fileUpload").get("v.files");
        var fileName = [];
        Array.from(files).forEach((file,index) => {
            fileName.push(file.name);
        });
        component.set("v.fileName",fileName);
    },
     uploadFiles: function(component, event, helper){
        $A.util.removeClass(component.find("mySpinner"),"slds-hide"); 
        var files = component.find("fileUpload").get("v.files");
         if(!$A.util.isEmpty(files) && !$A.util.isUndefinedOrNull(files)){
             if(files.length > 0){
                 helper.uploadFiles(component, event, helper, files);
             }
             else{
                 $A.util.addClass(component.find("mySpinner"),"slds-hide"); 
                  helper.showToast(component, 'error', 'Please Select File to Upload')
             }
         }
         else{
             $A.util.addClass(component.find("mySpinner"),"slds-hide"); 
             helper.showToast(component, 'error', 'Please Select File to Upload');         
         }
     },        
})