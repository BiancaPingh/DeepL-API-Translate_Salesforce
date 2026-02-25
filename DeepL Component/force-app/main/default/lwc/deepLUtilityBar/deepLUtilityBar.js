import { LightningElement, track, api, wire } from 'lwc';
import translateText from '@salesforce/apex/DeepLService.translateText';
import initiateDocumentUpload from '@salesforce/apex/DeepLService.initiateDocumentUpload';
import checkDocumentStatus from '@salesforce/apex/DeepLService.checkDocumentStatus';
import downloadDocument from '@salesforce/apex/DeepLService.downloadDocument';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { EnclosingTabId, getEnclosingTabId, openTab, getTabInfo } from 'lightning/platformUtilityBarApi';
import userId from '@salesforce/user/Id';
import getFilesFromSalesforce from '@salesforce/apex/SFfiles.getFilesFromSalesforce';

export default class DeepLUtilityBar extends LightningElement {
    @api recordId;
    @track sourceLang = 'auto'; // Default to auto-detect
    @track targetLang = 'EN-US'; // Default
    @track formality = 'default';
    @track inputText = '';
    @track translatedText = '';
    @track isTranslating = false;
    @track error;
    
    // File upload tracking
    @track fileStatus = '';
    @track isFileProcessing = false;
    @track downloadUrl;
    userId = userId;

    // Options for picklists
    get sourceLangOptions() {
        return [
            { label: 'Auto-detect', value: 'auto' },
            { label: 'Bulgarian', value: 'BG' },
            { label: 'Czech', value: 'CS' },
            { label: 'Danish', value: 'DA' },
            { label: 'German', value: 'DE' },
            { label: 'Greek', value: 'EL' },
            { label: 'English', value: 'EN' },
            { label: 'Spanish', value: 'ES' },
            { label: 'Estonian', value: 'ET' },
            { label: 'Finnish', value: 'FI' },
            { label: 'French', value: 'FR' },
            { label: 'Hungarian', value: 'HU' },
            { label: 'Indonesian', value: 'ID' },
            { label: 'Italian', value: 'IT' },
            { label: 'Japanese', value: 'JA' },
            { label: 'Korean', value: 'KO' },
            { label: 'Lithuanian', value: 'LT' },
            { label: 'Latvian', value: 'LV' },
            { label: 'Norwegian', value: 'NB' },
            { label: 'Dutch', value: 'NL' },
            { label: 'Polish', value: 'PL' },
            { label: 'Portuguese', value: 'PT' },
            { label: 'Romanian', value: 'RO' },
            { label: 'Russian', value: 'RU' },
            { label: 'Slovak', value: 'SK' },
            { label: 'Slovenian', value: 'SL' },
            { label: 'Swedish', value: 'SV' },
            { label: 'Turkish', value: 'TR' },
            { label: 'Ukrainian', value: 'UK' },
            { label: 'Chinese', value: 'ZH' }
        ];
    }

    get targetLangOptions() {
        // Target languages (English split into US/GB, PT split, etc based on DeepL API)
        return [
            { label: 'Bulgarian', value: 'BG' },
            { label: 'Czech', value: 'CS' },
            { label: 'Danish', value: 'DA' },
            { label: 'German', value: 'DE' },
            { label: 'Greek', value: 'EL' },
            { label: 'English (US)', value: 'EN-US' },
            { label: 'English (GB)', value: 'EN-GB' },
            { label: 'Spanish', value: 'ES' },
            { label: 'Estonian', value: 'ET' },
            { label: 'Finnish', value: 'FI' },
            { label: 'French', value: 'FR' },
            { label: 'Hungarian', value: 'HU' },
            { label: 'Indonesian', value: 'ID' },
            { label: 'Italian', value: 'IT' },
            { label: 'Japanese', value: 'JA' },
            { label: 'Korean', value: 'KO' },
            { label: 'Lithuanian', value: 'LT' },
            { label: 'Latvian', value: 'LV' },
            { label: 'Norwegian', value: 'NB' },
            { label: 'Dutch', value: 'NL' },
            { label: 'Polish', value: 'PL' },
            { label: 'Portuguese', value: 'PT-PT' },
            { label: 'Portuguese (Brazil)', value: 'PT-BR' },
            { label: 'Romanian', value: 'RO' },
            { label: 'Russian', value: 'RU' },
            { label: 'Slovak', value: 'SK' },
            { label: 'Slovenian', value: 'SL' },
            { label: 'Swedish', value: 'SV' },
            { label: 'Turkish', value: 'TR' },
            { label: 'Ukrainian', value: 'UK' },
            { label: 'Chinese', value: 'ZH' }
        ];
    }

    get formalityOptions() {
        return [
            { label: 'Default', value: 'default' },
            { label: 'More Formal', value: 'more' },
            { label: 'Less Formal', value: 'less' }
        ];
    }

    get acceptedFormats() {
        return ['.docx', '.pptx', '.pdf', '.txt'];
    }

    handleSourceChange(event) {
        this.sourceLang = event.detail.value;
    }

    handleTargetChange(event) {
        this.targetLang = event.detail.value;
    }

    handleFormalityChange(event) {
        this.formality = event.detail.value;
    }

    handleInputChange(event) {
        this.inputText = event.detail.value;
    }

    async handleTranslateText() {
        if (!this.inputText) return;
        
        this.isTranslating = true;
        this.error = null;
        this.translatedText = '';
        
        try {
            const result = await translateText({
                text: this.inputText,
                targetLang: this.targetLang,
                sourceLang: this.sourceLang,
                formality: this.formality
            });
            this.translatedText = result;
        } catch (error) {
            console.error('Translation error', error);
            let message = 'Translation failed. Please check your API Limits or Credentials.';
            if (error.body && error.body.message) {
                try {
                    message = error.body.message;
                } catch (e) {
                    message = error.body.message;
                }
            } else if (error.message) {
                message = error.message;
            }
            this.error = message;
             this.showToast('Error', message, 'error');
        } finally {
            this.isTranslating = false;
        }
    }

    // File Upload Handlers
    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length === 0) return;
        
        const contentVersionId = uploadedFiles[0].contentVersionId;
        const fileName = uploadedFiles[0].name;

        this.fileStatus = 'Uploading to DeepL...';
        this.isFileProcessing = true;
        this.downloadUrl = null;

        try {
            const result = await initiateDocumentUpload({
                contentVersionId: contentVersionId,
                targetLang: this.targetLang,
                sourceLang: this.sourceLang
            });
            
            const { document_id, document_key } = result;
            this.fileStatus = 'Translating...';
            
            // Start polling
            this.pollStatus(document_id, document_key, fileName);

        } catch (error) {
            this.fileStatus = 'Upload failed.';
            this.isFileProcessing = false;
            console.error('File upload error', error);
            
            let message = 'File upload failed.';
            if (error.body && error.body.message) {
                message = error.body.message;
            } else if (error.message) {
                message = error.message;
            }
            
            this.showToast('Error', message, 'error');
        }
    }

    async pollStatus(documentId, documentKey, originalFileName) {
        const pollInterval = 3000; // 3 seconds
        
        const intervalId = setInterval(async () => {
            try {
                const statusResult = await checkDocumentStatus({
                    documentId: documentId, 
                    documentKey: documentKey
                });
                
                const status = statusResult.status;
                this.fileStatus = `Status: ${status}`; // queued, translating, done, error

                if (status === 'done') {
                    clearInterval(intervalId);
                    this.downloadTranslatedFile(documentId, documentKey, originalFileName);
                } else if (status === 'error') {
                    clearInterval(intervalId);
                    this.fileStatus = 'Error during translation.';
                    this.isFileProcessing = false;
                }
            } catch (error) {
                clearInterval(intervalId);
                this.fileStatus = 'Polling failed.';
                this.isFileProcessing = false;
            }
        }, pollInterval);
    }

    async downloadTranslatedFile(documentId, documentKey, originalFileName) {
        this.fileStatus = 'Downloading...';
        try {
            const newContentVersionId = await downloadDocument({
                documentId: documentId,
                documentKey: documentKey,
                originalFileName: originalFileName
            });
            
            this.fileStatus = 'Complete!';
            this.isFileProcessing = false;
            
            // Generate download URL for the new file
            // /sfc/servlet.shepherd/version/download/068...
            this.downloadUrl = `/sfc/servlet.shepherd/version/download/${newContentVersionId}`;
            
            this.showToast('Success', 'File translated successfully!', 'success');

        } catch (error) {
            this.fileStatus = 'Download failed.';
            this.isFileProcessing = false;
            console.error('Download error', error);
        }
    }

    handleCopy() {
        // Create a temporary input element
        const input = document.createElement('textarea');
        input.value = this.translatedText;
        document.body.appendChild(input);
        input.select();
        
        try {
            const successful = document.execCommand('copy');
            const msg = successful ? 'successful' : 'unsuccessful';
            if (successful) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Translation copied to clipboard.',
                        variant: 'success'
                    })
                );
            } else {
                 this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Info',
                        message: 'Unable to copy. Please select and copy manually.',
                        variant: 'info'
                    })
                );
            }
        } catch (err) {
            console.error('Oops, unable to copy', err);
             this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Copy failed.',
                    variant: 'error'
                })
            );
        }
        document.body.removeChild(input);
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    // File selection
    @track selectedFile;
    @track selectedFileName;
    @track fileOptions = [];
    @track fileLookup = {};

    connectedCallback() {
        this.loadFiles();
    }

    loadFiles() {
        getFilesFromSalesforce()
            .then(result => {
                this.fileOptions = result.map(file => ({ label: file.Title, value: file.Id }));
                // Store filename lookup
                result.forEach(file => {
                    this.fileLookup[file.Id] = file.FileName;
                });
            })
            .catch(error => {
                console.error('Error fetching files:', error);
            });
    }

    async handleTranslateSelectedFile() {
        if (!this.selectedFile) {
            this.showToast('Error', 'Please select a file to translate.', 'error');
            return;
        }
        this.fileStatus = 'Uploading to DeepL...';
        this.isFileProcessing = true;
        this.downloadUrl = null;
        
        // Get the filename for the selected file
        const fileName = this.fileLookup[this.selectedFile] || 'TranslatedFile';
        
        try {
            const result = await initiateDocumentUpload({
                contentVersionId: this.selectedFile,
                targetLang: this.targetLang,
                sourceLang: this.sourceLang
            });
            const { document_id, document_key } = result;
            this.fileStatus = 'Translating...';
            this.pollStatus(document_id, document_key, fileName);
        } catch (error) {
            this.fileStatus = 'Upload failed.';
            this.isFileProcessing = false;
            this.showToast('Error', error.body && error.body.message ? error.body.message : 'File upload failed.', 'error');
        }
    }

    handleFileChange(event) {
        this.selectedFile = event.detail.value;
        this.selectedFileName = this.fileLookup[this.selectedFile];
    }
}
