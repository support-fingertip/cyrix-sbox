import {LightningElement, api} from 'lwc';
import saveFile from '@salesforce/apex/FileController.saveFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 

export default class CaptureImageLwc extends LightningElement {

    @api recordId;
    @api uniqueId;
    @api openCameraValue = false;

    isToggle = false;
    onClickPhoto = true;
    videoElement;
    canvasElement;
    buttonLable ='Take Photo';
    showCaptureButton = false;
    showStartButton = true;
    showSaveButton = false;
    showSpinner  =false;
    isCameraPermission = false;
    isCameraInitialized = false;
    
	connectedCallback() {
        console.log('Current Record ID:', this.recordId);
     //   alert(this.recordId);
    }
    renderedCallback() {
        this.videoElement = this.template.querySelector('.videoElement');
        this.canvasElement = this.template.querySelector('.canvas');
        if(this.openCameraValue && this.onClickPhoto && !this.isCameraInitialized){
            this.CheckCameraPermission();
        } 
    }
    @api
    stopCamerafromParent() {
        try {
            if(this.showCaptureButton)
            {
                this.stopCamera();
            }
       
         } catch (err) {
            console.error('Error stopping camera:', err);
        }
    }

    CheckCameraPermission(){
        this.showSaveButton = false;
        // First try to stop any existing stream
        this.stopExistingStream();
        navigator.mediaDevices.getUserMedia({ video: true })
        .then((stream) =>{
            stream.getTracks().forEach(track => track.stop());
            this.isCameraInitialized = true;
            this.initCamera();
            this.isCameraPermission = false;
        })
        .catch((error)=>{
            // User has denied permission
            this.isCameraInitialized = false;
          
            this.isCameraPermission = true;

            if (error.name === 'NotReadableError' || error.name === 'AbortError') {
                this.genericToastEvent('Error', 'Camera is already in use by another tab or app. Please close it and try again.', 'error');
                alert('Camera is already in use by another tab or app. Please close it and try again.');
            } 
            else
            {
                alert('Please give camera permission for the salesforce app and restart the app');
                this.genericToastEvent('Error','Please give camera permission for the salesforce app and restart the app','error');
            }





        });
        if(this.isCameraPermission){
            this.genericToastEvent('Error', 'Camera is already in use by another tab or app. Please close it and try again.', 'error');
            alert('Camera is already in use by another tab or app. Please close it and try again.');
        }
    }

    async initCamera() {
        if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
            try {
                this.showCaptureButton =true;
                this.showStartButton = false;
                this.showSaveButton = false;
                this.hideImageElement();
                // By default, use the front camera
                const constraints = { video: { facingMode: 'environment' }, audio: false };
                this.videoElement.srcObject = await navigator.mediaDevices.getUserMedia(constraints);
            } catch (error) {
                console.error('Error accessing the camera: ', JSON.stringify(error));
            }
        } else {
            
            console.error('getUserMedia is not supported in this browser');
        }
    }
    async captureImage() {
        if(this.videoElement && this.videoElement.srcObject !== null) {
            this.onClickPhoto = false;
            this.canvasElement.height = this.videoElement.videoHeight;
            this.canvasElement.width = this.videoElement.videoWidth;
            const context = this.canvasElement.getContext('2d');
            context.drawImage(this.videoElement, 0, 0, this.canvasElement.width, this.canvasElement.height);
            const imageData = this.canvasElement.toDataURL('image/png');
            const imageElement = this.template.querySelector('.imageElement');
            imageElement.setAttribute('src', imageData);
            
            // stop camera
            this.showCaptureButton = false;
            this.showSaveButton = true;
            this.showStartButton = true;
            this.buttonLable ='Re-take';
            const video = this.template.querySelector(".videoElement");
            video.srcObject.getTracks().forEach((track) => track.stop());
            video.srcObject = null;
            
			// show capture image
            imageElement.classList.add('slds-show');
            imageElement.classList.remove('slds-hide');
            
            this.template.querySelector('.camera-container').classList.add('image-captured');
						
        }
    }
	async saveImage() {
        this.showSpinner = true;

        if (!navigator.onLine) {
            this.showSpinner = false;
            const offlineToastEvent = new ShowToastEvent({
                title: 'Error',
                message: 'No internet connection. Please check your connection and try again.',
                variant: 'info'
            });
            this.dispatchEvent(offlineToastEvent);
            return;
        }

        try {
            // ✅ Step 1: Create a temporary smaller canvas
            const scaleFactor = 0.5; // 50% size, adjust as needed
            const tempCanvas = document.createElement('canvas');
            tempCanvas.width = this.canvasElement.width * scaleFactor;
            tempCanvas.height = this.canvasElement.height * scaleFactor;

            const ctx = tempCanvas.getContext('2d');
            ctx.drawImage(this.canvasElement, 0, 0, tempCanvas.width, tempCanvas.height);

            // ✅ Step 2: Convert to JPEG with compression (quality: 0.7)
            const compressedDataUrl = tempCanvas.toDataURL('image/jpeg', 0.7);

            const fileName = 'captured_image.jpg';
            console.log('Current Record ID:', this.recordId);

            // ✅ Step 3: Save compressed image
            const result = await saveFile({
                parentId: this.recordId,
                fileName: fileName,
                base64Data: compressedDataUrl.split(',')[1],
                uniqueId: this.uniqueId
            });
//,
            console.log('Content Version uploaded successfully:', result);
            this.buttonLable = 'Take Photo';
            this.showCaptureButton = false;
            this.showStartButton = true;
            this.showSaveButton = false;
            this.showSpinner = false;
            this.hideImageElement();

            const toastEvent = new ShowToastEvent({
                title: 'Success',
                message: 'Image saved successfully',
                variant: 'success'
            });
            this.dispatchEvent(toastEvent);

            this.dispatchEvent(new CustomEvent('camerastopped', {
                detail: { message: 'Camera closed successfully' }
            }));

        } catch (error) {
            this.showSpinner = false;
            console.error('Error uploading content version:', error.body ? error.body.message : error);
            const toastEvent = new ShowToastEvent({
                title: 'Error',
                message: 'Failed to save the image. Please refresh and try again.',
                variant: 'error'
            });
            this.dispatchEvent(toastEvent);
        }
    }

    closeOpenedCamera(){
        this.isToggle = false;
        this.stopCamera();
        
        this.dispatchEvent(new CustomEvent('camerastopped', {
            detail: { message: 'Camera closed successfully' }
        }));
    }
    async stopCamera(){
        const video = this.template.querySelector(".videoElement");
        video.srcObject.getTracks().forEach((track) => track.stop());
        video.srcObject = null;
        this.hideImageElement();
		this.showCaptureButton =false;
		this.showStartButton = true;
		this.buttonLable ='Take Photo';
    }
   

    
    stopExistingStream() {
        const video = this.template.querySelector(".videoElement");
        if (video && video.srcObject) {
            video.srcObject.getTracks().forEach(track => track.stop());
            video.srcObject = null;
            this.isCameraInitialized = false; // Reset flag
        }
    }
	async toggleCamera() {
        this.isToggle = true;
        this.onClickPhoto = false;
        const videoTracks = this.videoElement.srcObject.getVideoTracks();
        const currentFacingMode = videoTracks[0].getSettings().facingMode;
            
        // Toggle between front and back cameras
        const newFacingMode = currentFacingMode === 'user' ? 'environment' : 'user';

        // Stop the current tracks
        this.stopCamera();
        
        
        // Start the new tracks with updated constraints
        const constraints = { video: { facingMode: newFacingMode }, audio: false };
        this.videoElement.srcObject = await navigator.mediaDevices.getUserMedia(constraints);
        this.showCaptureButton =true;
        this.showStartButton = false;
        this.showSaveButton = false;
        this.hideImageElement();		
    }


    //Helper Methods
    dispatchToAura(textMessage){
        // Created a custom event to Pass to aura component
        const event =  new CustomEvent('closepopup', {
            detail: {
                eventType: textMessage,
            },
          });
          // Dispatch the event.
        this.dispatchEvent(event);
    }
    genericToastEvent(title,message,variant){
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
    hideImageElement(){
        const imageElement = this.template.querySelector('.imageElement');
        imageElement.setAttribute('src', "");
        imageElement.classList.add('slds-hide');
        imageElement.classList.remove('slds-show');
    }
}