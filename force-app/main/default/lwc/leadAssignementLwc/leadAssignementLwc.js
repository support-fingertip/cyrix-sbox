import { LightningElement,api,track ,wire} from 'lwc';
import {ShowToastEvent} from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import fetchLead from '@salesforce/apex/leadCmpController.fetchLead';
import leadAssignment from '@salesforce/apex/leadCmpController.leadAssignment';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class LeadAssignementLwc extends LightningElement {

@api recordId
@track regionRecord={};
@track subRegionRecord={};
@track subRegions=[];
@track selectVal;
@track leadOwnerId;
@track subRegionVal;
selectOptions = [
    {
        label: '--None--',
        value: '',
    },
{
    label: 'ASM Transfer',
    value: 'ASM Transfer',
},
{
label: 'Sales Engineer Transfer',
    value: 'Sales Engineer Transfer',
},
];
@track  subRegionOptions=[ {
        label: '--None--',
        value: '',
    },
];


@wire(fetchLead,{ leadId: '$recordId'}) 
regionsData({ error, data }) {
    if (data) {
  this.regionRecord = data.region;
this.subRegions=data.subRegions;
data.subRegions.forEach(element => {
this.subRegionOptions.push({label:element.Name,value:element.Id});

});

 this.error = undefined;

    } else if (error) {
      //console.log('Error block');
       this.error = error;
         this.regionRecord = null;

        const evt = new ShowToastEvent({
    title: 'Error ',
    message: error.body.message,
    variant: 'error',
    mode:'dismissible'
});
this.dispatchEvent(evt);
}else{
this.regionRecord = null;
}
}
get isSelectedASM() {
    if(this.selectVal=='ASM Transfer')
        return true;
    else
        return false;
}
get isSelectedSalesExe() {
    if(this.selectVal=='Sales Engineer Transfer')
        return true;
    else
        return false;
}

get isManagerUser(){
    if(this.subRegionRecord.ASM__c != null)
        return true;
    else
        return false;
}
get isSalesExe(){
    if(this.subRegionRecord.Sales_Engineer__c!=null)
        return true;
    else
        return false;
}

get isEnableSubmit(){
if(this.selectVal!='' && this.selectVal!=null && this.regionRecord != null){
    if(this.selectVal=='ASM Transfer' && this.isManagerUser){
    return false;
}else if(this.selectVal =='Sales Engineer Transfer' && this.isSalesExe){
    return false;
}else{
    return true;
}
}
else{
        return true;
}

}
handleChange(event) {
    this.selectVal = event.detail.value;
    if(this.selectVal=='ASM Transfer' && this.isManagerUser){
        this.leadOwnerId=this.subRegionRecord.ASM__c;
    }else if(this.selectVal =='Sales Engineer Transfer' && this.isSalesExe){
        this.leadOwnerId=this.subRegionRecord.Sales_Engineer__c;
    }else{
        this.leadOwnerId=null;
    }
        
}
handleSubRegion(event) {
    try{
    this.subRegionVal = event.detail.value;
    this.subRegionRecord = this.subRegions.find( subRegion => subRegion.Id === this.subRegionVal);
    }catch(e){
        console.error('Error in handleSubRegion'+e);
    }
}

doSubmit(event) {
        leadAssignment({  leadOwnerId : this.leadOwnerId ,leadId : this.recordId})  
                .then(result => { 
        const evt = new ShowToastEvent({
        title: 'lead Assignment',
        message: 'Lead Assignment is successful ',
    variant: 'success',
    mode:'dismissible'
    });

this.dispatchEvent(evt);
this.closeModel();
        })
.catch(error => {
this.error = error;
const evt = new ShowToastEvent({
        title: 'Error ',
        message: error.body.message,
        variant: 'error',
        mode:'dismissible'
    });

    this.dispatchEvent(evt);
});

}

get isSubRegion() {
    if(this.subRegionVal !=null)
        return true;
    else
        return false;
}


get isregionRecord(){
    if(this.regionRecord)
        return true;
    else
        return false;
}
closeModel() {
    this.dispatchEvent(new CloseActionScreenEvent());
}


}