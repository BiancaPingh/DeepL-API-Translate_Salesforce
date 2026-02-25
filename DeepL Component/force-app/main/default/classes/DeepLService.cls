public with sharing class DeepLService {
    
    //API endpoints
    private static final String ENDPOINT_TRANSLATE = 'callout:DeepL_API/v2/translate';
    private static final String ENDPOINT_DOCUMENT = 'callout:DeepL_API/v2/document';
    
    /**
     * Translates text using the DeepL API.
     * @param text The text to translate.
     * @param targetLang The target language code (e.g., 'DE', 'FR').
     * @param sourceLang The source language code (optional).
     * @param formality The formality level ('default', 'more', 'less').
     * @return The translated text.
     */
    @AuraEnabled
    public static String translateText(String text, String targetLang, String sourceLang, String formality) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT_TRANSLATE);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'text=' + EncodingUtil.urlEncode(text, 'UTF-8');
        body += '&target_lang=' + EncodingUtil.urlEncode(targetLang, 'UTF-8');
        
        if (String.isNotBlank(sourceLang) && sourceLang != 'auto') {
            body += '&source_lang=' + EncodingUtil.urlEncode(sourceLang, 'UTF-8');
        }
        
        if (String.isNotBlank(formality) && formality != 'default') {
            body += '&formality=' + EncodingUtil.urlEncode(formality, 'UTF-8');
        }
        
        // Handling for rich text preservation
        body += '&tag_handling=xml'; 
        
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> translations = (List<Object>) responseMap.get('translations');
            Map<String, Object> firstTranslation = (Map<String, Object>) translations[0];
            return (String) firstTranslation.get('text');
        } else {
            throw new AuraHandledException('Error calling DeepL API: ' + res.getStatus() + ' ' + res.getBody());
        }
    }

    /**
     * Initiates a document upload for translation.
     * @param contentVersionId The ID of the ContentVersion record to upload.
     * @param targetLang The target language code.
     * @param sourceLang The source language code (optional).
     * @return A map containing document_id and document_key.
     */
    @AuraEnabled
    public static Map<String, String> initiateDocumentUpload(Id contentVersionId, String targetLang, String sourceLang) {
        List<ContentVersion> cvList = [SELECT Title, PathOnClient, VersionData FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        if (cvList.isEmpty()) {
            throw new AuraHandledException('ContentVersion not found for Id: ' + contentVersionId);
        }
        ContentVersion cv = cvList[0];
        
        String boundary = '----------------------------' + String.valueOf(DateTime.now().getTime());
        String header = '--' + boundary + '\r\n' +
                        'Content-Disposition: form-data; name="file"; filename="' + cv.PathOnClient + '"\r\n' +
                        'Content-Type: application/octet-stream\r\n\r\n';
        String footer = '\r\n--' + boundary + '--';
        
        String bodyStart = '--' + boundary + '\r\n' +
                           'Content-Disposition: form-data; name="target_lang"\r\n\r\n' + targetLang + '\r\n';
                           
        if (String.isNotBlank(sourceLang) && sourceLang != 'auto') {
            bodyStart += '--' + boundary + '\r\n' +
                         'Content-Disposition: form-data; name="source_lang"\r\n\r\n' + sourceLang + '\r\n';
        }       

        // Combine parts. simple string concatenation with blob is not directly possible for body.
        
        // Combine parts using Hex encoding to safely join Blobs
        String combinedHeaderStr = bodyStart + header; // This is the string part before the file blob
        String combinedHeaderHex = EncodingUtil.convertToHex(Blob.valueOf(combinedHeaderStr)); // Convert header to hex
        String fileHex = EncodingUtil.convertToHex(cv.VersionData); // Convert file blob to hex
        String footerHex = EncodingUtil.convertToHex(Blob.valueOf(footer)); // Convert footer to hex
        
        Blob bodyBlob = EncodingUtil.convertFromHex(combinedHeaderHex + fileHex + footerHex); // Combine all parts into a single blob

        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT_DOCUMENT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(bodyBlob);
        req.setTimeout(120000); // 2 minutes timeout for upload

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return new Map<String, String>{
                'document_id' => (String) responseMap.get('document_id'),
                'document_key' => (String) responseMap.get('document_key')
            };
        } else {
            // Enhanced error message with status code and response details
            String errorMsg = 'Error uploading document (Status ' + res.getStatusCode() + '): ' + res.getStatus();
            if (String.isNotBlank(res.getBody())) {
                errorMsg += '. Response: ' + res.getBody();
            }
            if (res.getStatusCode() == 503) {
                errorMsg += '. DeepL service may be temporarily unavailable. Please try again later.';
            } else if (res.getStatusCode() == 429) {
                errorMsg += '. API rate limit exceeded. Please wait before trying again.';
            } else if (res.getStatusCode() == 413) {
                errorMsg += '. File is too large. Maximum file size is 30MB.';
            } else if (res.getStatusCode() == 456) {
                errorMsg += '. Document translation quota exceeded.';
            }
            throw new AuraHandledException(errorMsg);
        }
    }

    /**
     * Checks the status of a document translation.
     * @param documentId The document ID.
     * @param documentKey The document encryption key.
     * @return The status string (queued, translating, done, error).
     */
    @AuraEnabled
    public static Map<String, Object> checkDocumentStatus(String documentId, String documentKey) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT_DOCUMENT + '/' + documentId);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'document_key=' + EncodingUtil.urlEncode(documentKey, 'UTF-8');
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
             return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new AuraHandledException('Error checking status: ' + res.getStatus());
        }
    }

    /**
     * Downloads the translated document and saves it as a ContentVersion.
     * @param documentId The document ID.
     * @param documentKey The document encryption key.
     * @param originalFileName The name of the original file.
     * @return The Id of the new ContentVersion.
     */
    @AuraEnabled
    public static Id downloadDocument(String documentId, String documentKey, String originalFileName) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT_DOCUMENT + '/' + documentId + '/result');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'document_key=' + EncodingUtil.urlEncode(documentKey, 'UTF-8');
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            ContentVersion cv = new ContentVersion();
            cv.VersionData = res.getBodyAsBlob();
            cv.Title = 'Translated_' + originalFileName;
            cv.PathOnClient = 'Translated_' + originalFileName;
            insert cv;
            return cv.Id;
        } else {
            throw new AuraHandledException('Error downloading document: ' + res.getStatus());
        }
    }
}
