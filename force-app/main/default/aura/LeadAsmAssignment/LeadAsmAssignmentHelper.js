({
    showToast: function(title,msg,type){
        var toastEvent = $A.get("e.force:showToast");
        toastEvent.setParams({
            "title": title,
            "message": msg,
            "type":type
        });
        toastEvent.fire(); 
        $A.get('e.force:refreshView').fire();
    },
})