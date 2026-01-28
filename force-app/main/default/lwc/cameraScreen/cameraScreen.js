import { LightningElement, api } from 'lwc';
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
    buttonLable = 'Take Photo';
    showCaptureButton = false;
    showStartButton = true;
    showSaveButton = false;
    showSpinner = false;
 isCameraPermission = false;
    isCameraInitialized = false;

    connectedCallback() {
        console.log('Current Record ID:', this.recordId);
    }

    renderedCallback() {
        this.videoElement = this.template.querySelector('.videoElement');
        this.canvasElement = this.template.querySelector('.canvas');
        if (this.openCameraValue && this.onClickPhoto && !this.isCameraInitialized)  {
            this.CheckCameraPermission();
        }
    }
  stopExistingStream() {
        const video = this.template.querySelector(".videoElement");
        if (video && video.srcObject) {
            video.srcObject.getTracks().forEach(track => track.stop());
            video.srcObject = null;
            this.isCameraInitialized = false; // Reset flag
        }
    }
    genericToastEvent(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
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
                this.showCaptureButton = true;
                this.showStartButton = false;
                this.showSaveButton = false;
                this.hideImageElement();

                const constraints = { video: { facingMode: 'environment' }, audio: false };
                this.videoElement.srcObject = await navigator.mediaDevices.getUserMedia(constraints);
            } catch (error) {
                // FIXED: Proper error logging
                console.error('Error accessing the camera:', error);
                console.error('Error name:', error.name);
                console.error('Error message:', error.message);
                
                // Show user-friendly message
                let errorMessage = 'Cannot access camera. ';
                
                if (error.name === 'NotAllowedError' || error.name === 'PermissionDeniedError') {
                    errorMessage = 'Camera permission was denied. Please grant camera access in your browser settings.';
                } else if (error.name === 'NotFoundError' || error.name === 'DevicesNotFoundError') {
                    errorMessage = 'No camera found on this device.';
                } else if (error.name === 'NotReadableError' || error.name === 'TrackStartError') {
                    errorMessage = 'Camera is already in use by another application.';
                } else if (error.name === 'OverconstrainedError' || error.name === 'ConstraintNotSatisfiedError') {
                    errorMessage = 'Camera constraints could not be satisfied.';
                } else {
                    errorMessage = 'Failed to access camera. Please check your camera settings.';
                }
                
                this.genericToastEvent('Camera Error', errorMessage, 'error');
            }
        } else {
            console.error('getUserMedia is not supported in this browser');
            this.genericToastEvent('Error', 'Camera not supported in your browser', 'error');
        }
    }

    async captureImage() {
        if (this.videoElement && this.videoElement.srcObject !== null) {
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
            this.buttonLable = 'Re-take';
            const video = this.template.querySelector(".videoElement");
            if (video && video.srcObject) {
                video.srcObject.getTracks().forEach((track) => track.stop());
                video.srcObject = null;
            }

            // show capture image
            imageElement.classList.add('slds-show');
            imageElement.classList.remove('slds-hide');

            this.template.querySelector('.camera-container').classList.add('image-captured');
        }
    }

    async saveImage() {
        if (!navigator.onLine) {
            this.genericToastEvent('Error', 'No internet connection. Please check your connection and try again.', 'info');
            return;
        }

        const imageData = this.canvasElement.toDataURL('image/png');
        const fileName = 'captured_image.png';
        console.log('Current Record ID:', this.recordId);

        try {
            this.showSpinner = true;
            const result = await saveFile({
                parentId: this.recordId,
                fileName: fileName,
                base64Data: imageData.split(',')[1]
            });

            console.log('Content Version uploaded successfully:', result);
            this.buttonLable = 'Take Photo';
            this.showCaptureButton = false;
            this.showStartButton = true;
            this.showSaveButton = false;
            this.showSpinner = false;
            this.hideImageElement();
            this.closeOpenedCamera();

            var message;
            if (this.completeVisit) {
                message = new CustomEvent('myvisitclick', {
                    detail: {
                        message: 'camerScreen',
                        isPhotoTaken: true,
                    }
                });
                this.dispatchEvent(message);
            } else {
                message = new CustomEvent('myvisitclick', {
                    detail: {
                        message: 'executeScreen',
                        screen: 3.2,
                    }
                });
                this.dispatchEvent(message);
            }

            this.genericToastMessage('Success', 'Image saved successfully', 'success');

        } catch (error) {
            this.showSpinner = false;
            this.genericToastEvent('Error', 'Failed to save the image Please refresh and try again.', 'error');
            console.error('Error uploading content version:', error.body ? error.body.message : error.message);
        }
    }

    genericToastMessage(titles, msg, variants) {
        const toastEvent = new ShowToastEvent({
            title: titles,
            message: msg,
            variant: variants
        });
        this.dispatchEvent(toastEvent);
    }

    closeOpenedCamera() {
        this.isToggle = false;
        this.stopCamera();
    }

    async stopCamera() {
        const video = this.template.querySelector(".videoElement");
        if (video && video.srcObject) {
            video.srcObject.getTracks().forEach((track) => track.stop());
            video.srcObject = null;
        }
        this.hideImageElement();
        this.showCaptureButton = false;
        this.showStartButton = true;
        this.buttonLable = 'Take Photo';
        this.openCameraValue = !this.openCameraValue;
    }

    dispatchToAura(textMessage) {
        const event = new CustomEvent('closepopup', {
            detail: {
                eventType: textMessage,
            },
        });
        this.dispatchEvent(event);
    }

    hideImageElement() {
        const imageElement = this.template.querySelector('.imageElement');
        imageElement.setAttribute('src', "");
        imageElement.classList.add('slds-hide');
        imageElement.classList.remove('slds-show');
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

        this.showCaptureButton = true;
        this.showStartButton = false;
        this.showSaveButton = false;
        this.hideImageElement();
    }
}