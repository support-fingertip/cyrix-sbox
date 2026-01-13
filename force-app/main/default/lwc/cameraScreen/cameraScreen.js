import { LightningElement,api } from 'lwc';
import saveFile from '@salesforce/apex/beatPlannerlwc.saveFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'; 

export default class CameraScreen extends LightningElement { 
    @api recordId;
    @api openCameraValue = false;
    @api isDesktop;
    @api completeVisit;

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
    
    connectedCallback() {
  
        console.log('Current Record ID:', this.recordId);
    }
    renderedCallback() {
        this.videoElement = this.template.querySelector('.videoElement');
        this.canvasElement = this.template.querySelector('.canvas');
        if(this.openCameraValue && this.onClickPhoto){
            this.initCamera();
        }
    }

    genericToastEvent(title,message,variant){
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }

    CheckCameraPermission(){
    
        navigator.mediaDevices.getUserMedia({ video: true })
            .then((stream) =>{
                
                // User has granted permission
                // this.cameraPermissionGranted = true;
                stream.getTracks().forEach(track => track.stop());
                this.initCamera();
                this.isCameraPermission = false;
                this.openCameraValue = !this.openCameraValue;
            })
            .catch((error)=>{
                  
                // User has denied permission
                console.error('Access to camera was denied:', error);
                //this.cameraPermissionGranted = false;
                console.log('Camera permission not granted');
                this.genericToastEvent('Error','Give camera permission for the salesforce app and restart the app','error');
                this.isCameraPermission = true;
                alert('Give camera permission for the salesforce app and restart the app');
            });
            if(this.isCameraPermission){
                this.genericToastEvent('Error','Give camera permission for the salesforce app and restart the app','error');
                    alert('Give camera permission for the salesforce app and restart the app');
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
    async saveImage(){
        
        if (!navigator.onLine) {
            this.genericToastEvent('Error','No internet connection. Please check your connection and try again.','info');
               
            return;
        }

                const imageData = this.canvasElement.toDataURL('image/png');
                const fileName = 'captured_image.png';
                        console.log('Current Record ID:', this.recordId);
                try {
                const result = await saveFile({
                    parentId: this.recordId,
                    fileName: fileName,
                    base64Data: imageData.split(',')[1]
                });
                console.log('Content Version uploaded successfully:', result);
                this.buttonLable ='Take Photo';
                this.showCaptureButton = false;
                this.showStartButton = true;
                this.showSaveButton = false; 
                this.showSpinner = false;
                this.hideImageElement();
                this.closeOpenedCamera();
                var message;
                if(this.completeVisit){
                    message = new CustomEvent('myvisitclick', {
                        detail: {
                            message: 'camerScreen' ,
                            isPhotoTaken : true, 
                        }
                    });
                    this.dispatchEvent(message);
                }else{
                    message = new CustomEvent('myvisitclick', {
                        detail: {
                            message: 'executeScreen' ,
                            screen : 3.2,   
                        }
                    });
                    this.dispatchEvent(message);
                }
                this.genericToastMessage('Success','Image saved successfully','success');
                //this.dispatchEvent(message);
                this.closeOpenedCamera();
            } catch (error) {
                this.genericToastEvent('Error','Failed to save the image Please refresh and try again.','error');
                console.error('Error uploading content version:', error.body.message);
                
            }
    }

    genericToastMessage(titles,msg,variants){
        const toastEvent = new ShowToastEvent({
            title: titles,
            message: msg,
            variant: variants
        });
        this.dispatchEvent(toastEvent);
    }
    closeOpenedCamera(){
        this.isToggle = false;
        this.stopCamera();
    }
    async stopCamera(){

        const video = this.template.querySelector(".videoElement");
        video.srcObject = null;
        // video.srcObject.getTracks().forEach((track) => track.stop());
        // if (video.srcObject) {
        //     // Stop all media tracks (turn off the camera)
        //     video.srcObject.getTracks().forEach((track) => {
        //         track.stop();
        //     });
    
        //     // Clear the video stream
        //     video.srcObject = null;
        // }
        this.hideImageElement();
        this.showCaptureButton =false;
        this.showStartButton = true;
        this.buttonLable ='Take Photo';
        this.openCameraValue = !this.openCameraValue;
    }
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

    hideImageElement(){
        
        const imageElement = this.template.querySelector('.imageElement');
        imageElement.setAttribute('src', "");
        imageElement.classList.add('slds-hide');
        imageElement.classList.remove('slds-show');
    }

    // async toggleCamera() {
    //     this.isToggle = true;
    //     this.onClickPhoto = false;
    
    //     const devices = await navigator.mediaDevices.enumerateDevices();
    //     const videoDevices = devices.filter(device => device.kind === 'videoinput');
    //     alert(1);
    //     if (videoDevices.length < 2) {
    //         console.warn("Only one camera available.");
    //         alert(2);
    //         alert(videoDevices.length);
    //         return;
    //     }
    //     alert(3);
    //     const currentStream = this.videoElement.srcObject;
    //     const currentTrack = currentStream ? currentStream.getVideoTracks()[0] : null;
    //     const currentDeviceId = currentTrack ? currentTrack.getSettings().deviceId : null;
    
    //     // Find the next camera
    //     const nextCamera = videoDevices.find(device => device.deviceId !== currentDeviceId);
    //     alert(4);
    //     alert(nextCamera);
    //     if (nextCamera) {
    //         this.stopCamera();
    //         alert(5);
    //         const constraints = { video: { deviceId: { exact: nextCamera.deviceId } }, audio: false };
    //         alert(constraints);
    //         alert(6);
    //         try {
    //             this.videoElement.srcObject = await navigator.mediaDevices.getUserMedia(constraints);
    //             alert(5);
    //             this.showCaptureButton = true;
    //             this.showStartButton = false;
    //             this.showSaveButton = false;
    //             this.hideImageElement();
    //         } catch (error) {
    //             console.error("Error accessing camera:", error);
    //         }
    //     }
    // }
    
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
}