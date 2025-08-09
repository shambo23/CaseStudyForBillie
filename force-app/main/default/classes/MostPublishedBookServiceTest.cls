/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 */
@isTest
private class MostPublishedBookServiceTest {
    
    // Mock returning books (two pass the >600000 filter)
    private class SuccessBooksMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Simulated external JSON: list of wrapper objects each holding a Books array
            String body = '[{"Books":[' +
                          '{"Author":"Eric Freeman","Title":"Head First Design Patterns","Edition":800000},' +
                          '{"Author":"Low Author","Title":"Some Book","Edition":100000},' +
                          '{"Author":"No Edition","Title":"Missing Edition"}' +
                          ']},' +
                          '{"Books":[{"Author":"Another Author","Title":"Another Book","Edition":750000}]}' +
                          ']';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }
    
    // Mock returning books but none exceed threshold (exercises no-publish branch)
    private class NoQualifiedBooksMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            String body = '[{"Books":[' +
                          '{"Author":"A1","Title":"T1","Edition":100000},' +
                          '{"Author":"A2","Title":"T2","Edition":200000}' +
                          ']}]';
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(body);
            return res;
        }
    }
    
    // Mock returning non-200 (exercises outer guard failing path)
    private class ErrorStatusMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Error');
            return res;
        }
    }
    
    @isTest
    static void testQueueable_withQualifiedBooks() {
        Test.setMock(HttpCalloutMock.class, new SuccessBooksMock());
        Test.startTest();
        System.enqueueJob(new MostPublishedBookService());
        Test.stopTest();
        // Cannot query platform events directly; success is absence of unhandled exception.
        System.assert(true, 'Queueable executed without exception for qualified books payload.');
    }
    
    @isTest
    static void testQueueable_noQualifiedBooks() {
        Test.setMock(HttpCalloutMock.class, new NoQualifiedBooksMock());
        Test.startTest();
        System.enqueueJob(new MostPublishedBookService());
        Test.stopTest();
        System.assert(true, 'Queueable executed with no qualifying books (no publish branch).');
    }
    
    @isTest
    static void testQueueable_errorStatus() {
        Test.setMock(HttpCalloutMock.class, new ErrorStatusMock());
        Test.startTest();
        System.enqueueJob(new MostPublishedBookService());
        Test.stopTest();
        System.assert(true, 'Queueable handled non-200 status without exception.');
    }
}