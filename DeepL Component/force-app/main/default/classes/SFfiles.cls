public with sharing class SFfiles {
    public SFfiles() {

    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFilesFromSalesforce() {
        // Query to get the latest version of files from Salesforce
        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, PathOnClient 
            FROM ContentVersion 
            WHERE IsLatest = true
            ORDER BY Title ASC
        ];
        
        List<Map<String, String>> fileList = new List<Map<String, String>>();
        for (ContentVersion cv : versions) {
            Map<String, String> fileMap = new Map<String, String>();
            fileMap.put('Id', cv.Id);  // ContentVersionId
            fileMap.put('Title', cv.Title);
            fileMap.put('FileName', cv.PathOnClient);  // Full filename with extension
            fileMap.put('FileExtension', cv.FileExtension);
            fileList.add(fileMap);
        }
        return fileList;
    }
}