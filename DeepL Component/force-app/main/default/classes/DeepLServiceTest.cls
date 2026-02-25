@isTest
private class DeepLServiceTest {

    @isTest
    static void testTranslateText() {
        // Mock response
        Test.setMock(HttpCalloutMock.class, new DeepLMock('{"translations":[{"text":"Hallo Welt"}]}'));
        
        String result = DeepLService.translateText('Hello World', 'DE', 'EN', 'default');
        System.assertEquals('Hallo Welt', result);
    }

    @isTest
    static void testInitiateDocumentUpload() {
        // Create dummy ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Document',
            PathOnClient = 'Test.txt',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Retrieve the ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        Test.setMock(HttpCalloutMock.class, new DeepLMock('{"document_id":"doc123", "document_key":"key456"}'));
        
        Test.startTest();
        Map<String, String> result = DeepLService.initiateDocumentUpload(cv.Id, 'DE', 'EN');
        Test.stopTest();
        
        System.assertEquals('doc123', result.get('document_id'));
        System.assertEquals('key456', result.get('document_key'));
    }

    @isTest
    static void testCheckDocumentStatus() {
        Test.setMock(HttpCalloutMock.class, new DeepLMock('{"document_id":"doc123", "status":"done"}'));
        
        Map<String, Object> result = DeepLService.checkDocumentStatus('doc123', 'key456');
        System.assertEquals('done', result.get('status'));
    }

    @isTest
    static void testDownloadDocument() {
         // Mocking a blob response is tricky with simple string mock, but for coverage/logic check:
         // valid 200 OK with some body is enough to trigger the insert
        Test.setMock(HttpCalloutMock.class, new DeepLMock('Translated Content')); 
        
        try {
            DeepLService.downloadDocument('doc123', 'key456', 'Test.txt');
            
            // Verify content version created
            ContentVersion cv = [SELECT Id, Title FROM ContentVersion WHERE Title = 'Translated_Test.txt' LIMIT 1];
            System.assertNotEquals(null, cv);
        } catch (Exception e) {
             System.assert(false, 'Should not have thrown exception: ' + e.getMessage());
        }
    }

    // Inner class for Mock
    private class DeepLMock implements HttpCalloutMock {
        private String body;
        private Integer statusCode;
        
        public DeepLMock(String body) {
            this.body = body;
            this.statusCode = 200;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setBody(body);
            res.setStatusCode(statusCode);
            return res;
        }
    }
}
