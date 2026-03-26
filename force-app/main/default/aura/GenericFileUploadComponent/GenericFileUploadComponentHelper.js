({
    fetchUploadedFiles: function(component, recordId, documentName) {
        var action = component.get("c.getFiles");
        var documentList = component.get("v.displaySelectedDocs") ? component.get("v.docStringList") : '';
        console.log('documentList '+documentList);
        action.setParams({
            recordId: recordId,
            fileName: documentName || '',
            documentList: documentList
        });
        
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                var result = response.getReturnValue();
                component.set("v.contentDocIds",result);
                console.log('uploaded FIles '+ JSON.stringify(result));
            } else {
                console.log("Error fetching files: " + response.getError());
            }
        });
        
        $A.enqueueAction(action);
    },
    uploadFiles: function(component, event, helper, files){
        var self = this;
        Array.from(files).forEach((file,index) => {
            var readFile = new FileReader();
            readFile.onload = $A.getCallback(function() {
            var fileData = readFile.result;
            fileData = fileData.substring(fileData.indexOf('base64,') + 'base64,'.length)
            self.insertDocuments(component, event, helper, fileData, file);
        });
        readFile.readAsDataURL(file);
    });
},
 insertDocuments: function(component, event, helper, fileData, file){
    $A.util.removeClass(component.find("mySpinner"),"slds-hide");
    var parentId = component.get("v.recordId");
    var documentName = component.get("v.selectedDocumentName");
    var size = file.size;
    var actualFileName = documentName && documentName.trim() !== '' ? documentName : file.name;
    var fileName = file.name;
    var fileType = file.type; 
    var action1  = component.get("c.fileUpload");
    action1.setParams({
        'parentId': parentId,
        'name': fileName,
        'fileType': fileType,
        'fileData': fileData,
        'documentName':actualFileName,
    });
    action1.setCallback(this, function(response){
        var state = response.getState();
        $A.util.addClass(component.find("mySpinner"),"slds-hide");
        if(state === 'SUCCESS'){
            var result = response.getReturnValue();
            if(!$A.util.isEmpty(result) && !$A.util.isUndefinedOrNull(result)){
                var contentDocIds = component.get("v.contentDocIds");
                contentDocIds.push(result);
                component.set("v.contentDocIds",contentDocIds);
                var emptyFiles = [];
                component.find("fileUpload").set("v.files",null);
                component.set("v.fileName",emptyFiles);
                this.showToast(component, 'success','Document Inserted Successfully');
                this.fetchUploadedFiles(component, parentId, documentName);
                 $A.get('e.force:refreshView').fire();
            }
            else{
                this.showToast(component, 'error','Something went wrong, Not able to fetch ContentDocumentId');
            }
        }
        else{
            var errors = response.getError();
            if(errors){
                this.showToast(component, 'error','Exception occured');
            }
        }
    });
    $A.enqueueAction(action1);
},
    showToast: function(cmp, type, message){
        var notification = $A.get("e.force:showToast");
        notification.setParams({
            message: message,
            duration: '1000',
            type: type,
            mode: 'pester'
        });
        notification.fire();
    }
})