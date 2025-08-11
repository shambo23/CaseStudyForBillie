/**
 * MostPublishedBookService - This class calls Most Published Book API in Queueable context
**/
public with sharing class MostPublishedBookService implements Queueable, Database.AllowsCallouts {
    public void execute(QueueableContext context) {
        // Named Credential alias (Configured as 'Most_Published_Book')
        String endpoint = 'callout:Most_Published_Book';   
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);          // Use the Named Credential endpoint
        req.setMethod('GET');               // GET request to retrieve book data
        req.setTimeOut(120000);             // Optional: extend timeout to 120s
        Http http = new Http();
        HttpResponse res = http.send(req);  // Perform the callout
        
        // Proceed only if HTTP 200 OK and body not null
        if (res.getStatusCode() == 200 && res.getBody()!=null) {
            // Expecting top-level JSON as a List of Objects, each may contain a 'Books' array
            List<Object> rawResponse = (List<Object>) JSON.deserializeUntyped(res.getBody());
            // Will hold only qualifying book Maps (Edition > 600000)
            List<Map<String, Object>> filteredList = new List<Map<String, Object>>(); 
            // Iterate over outer array
            for (Object response : rawResponse) {
                Map<String, Object> bookDetails = (Map<String, Object>)response;
                // Guard: ensure object has 'Books' key
                if (bookDetails != null && bookDetails.containsKey('Books')) {
                    // Inner list of book entries
                    List<Object> innerBooks = (List<Object>) bookDetails.get('Books');
                    for (Object ibook : innerBooks) {
                        Map<String, Object> ibMap = (Map<String, Object>)ibook;
                        // Filter criterion: Edition exists and > 600000
                        if(ibMap.containsKey('Edition')  && (Integer)ibMap.get('Edition') > 600000) {
                            filteredList.add(ibMap);
                        }
                    }
                }
            }
            // Only proceed if at least one matching book
            if (!filteredList.isEmpty()) {
                // Sort descending by Edition using custom comparator
                filteredList.sort(new BookSortByEdition());
                // Publish platform event with serialized list of qualifying books
                EventBus.publish(new MostPublishedBooks__e(Books__c = JSON.serialize(filteredList)));
            }
        }
    }
    // Comparator class (Apex generics limited; attempting generic type causes errors in some org versions)
    // Compares two Map<String,Object> representations of books by 'Edition' value in descending order.
    private class BookSortByEdition implements System.Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> b1, Map<String, Object> b2) { 
            Integer result;
            // Both Editions null -> equal
            if(b1.get('Edition')==null && b2.get('Edition')==null) {
                result = 0;
            // First null -> goes after second (nulls last in descending sort)
            } else if(b1.get('Edition')==null) { 
                result = 1; 
            // Second null -> first comes first
            } else if(b2.get('Edition')==null) {
                result = -1;
            // If first Edition less than second -> second should precede (descending), return positive
            } else if((Integer)b1.get('Edition') < (Integer)b2.get('Edition')) {
                result = 1;
            // If first Edition greater than second -> first comes earlier, return negative
            } else if((Integer)b1.get('Edition') > (Integer)b2.get('Edition')) {
                result = -1;
            // Equal numeric Editions
            } else {
                result = 0;  
            } 
            return result;        
        }
    } 
}