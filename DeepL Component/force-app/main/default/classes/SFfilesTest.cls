@isTest
private class SFfilesTest {

    @isTest
    static void myUnitTest() {

        // Create a test file
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;

        Test.startTest();
        List<Map<String, String>> files = SFfiles.getFilesFromSalesforce();
        Test.stopTest();

        System.assert(!files.isEmpty(), 'Files list should not be empty');
        Boolean found = false;
        for(Map<String, String> fileMap : files) {
            if(fileMap.get('Id') == cv.Id) {
                found = true;
                System.assertEquals('Test File', fileMap.get('Title'), 'Title should match');
                System.assertEquals('TestFile.txt', fileMap.get('FileName'), 'FileName should match');
                System.assertEquals('txt', fileMap.get('FileExtension'), 'FileExtension should match');
                break;
            }
        }
        System.assert(found, 'Test file should be in the files list');
    }
}