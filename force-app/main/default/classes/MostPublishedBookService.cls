/**
 * Service: Fetches data from the "Most Published Book" external API (Queueable context)
 * Responsibilities:
 *  - Perform HTTP callout using metadata‑driven endpoint configuration (API_Detail_mdt)
 *  - Parse JSON payload
 *  - Filter qualifying books (by Edition threshold) and sort descending by Edition
 *  - Publish qualifying books via Platform Event (MostPublishedBooks__e)
 *
 * Improvements vs original:
 *  - Centralized constants (no scattered hard‑coded strings)
 *  - Structured error handling with specific catch blocks & logging
 *  - Guard clauses for null / unexpected shapes
 *  - Smaller, intention‑revealing private helper methods
 *  - Comparator simplified & null-safe
 */
public with sharing class MostPublishedBookService implements Queueable, Database.AllowsCallouts {

    /* =============================
       Constants / Config Defaults
       ============================= */
    // Name of the Custom Metadata record (API_Detail__mdt) holding endpoint, method, timeout, etc.
    private static final String API_METADATA_NAME = 'Most_Published_Book';
    // JSON key constants (avoid magic strings scattered throughout parsing logic)
    private static final String KEY_BOOKS         = 'Books';
    private static final String KEY_EDITION       = 'Edition';
    // Edition threshold (business rule: only consider books whose Edition exceeds this number).
    private static final Integer DEFAULT_EDITION_THRESHOLD = Book_Configuration__mdt.getInstance(API_METADATA_NAME)!=null ? Integer.valueOf(Book_Configuration__mdt.getInstance(API_METADATA_NAME).Default_Edition_Threshold__c) : 600000; 
    // HTTP success code constant (future: could expand to allow 2xx range if API changes)
    private static final Integer HTTP_SUCCESS     = 200;
    // Safety cap to help prevent Platform Event payload size overrun (approx 1MB total event limit).
    // Tune based on average serialized size per book or move to metadata if admins need runtime control.
    private static final Integer MAX_BOOKS_TO_PUBLISH = Book_Configuration__mdt.getInstance(API_METADATA_NAME)!=null ? Integer.valueOf(Book_Configuration__mdt.getInstance(API_METADATA_NAME).Max_Books_To_Publish__c) : 200;

    /* =============================
       Public Queueable Entry Point
       ============================= */
    /**
     * Queueable entry point.
     * Steps:
     *  1. Load API config from custom metadata.
     *  2. Execute HTTP callout.
     *  3. Validate success and non-empty body.
     *  4. Parse & filter qualifying books (Edition > threshold).
     *  5. Sort results by Edition descending.
     *  6. Apply safety cap to guard against oversize Platform Event payload.
     *  7. Publish Platform Event with JSON payload of qualifying books.
     * Error Handling: Each exception type is logged persistently via custom object (Exception_Log__c).
     */
    public void execute(QueueableContext context) {
        API_Detail__mdt apiDetail = API_Detail__mdt.getInstance(API_METADATA_NAME);
        if (apiDetail == null) {
            // Defensive exit: configuration missing (deploy / metadata load issue)
            return; 
        }
        try {
            HttpResponse response = performCallout(apiDetail);
            if (!isSuccessResponse(response)) {
                // Non-200 or empty body; treat as non-fatal (no retry logic built in here)
                return;
            }
            List<Map<String, Object>> qualifyingBooks = extractQualifyingBooks(response.getBody());
            if (qualifyingBooks.isEmpty()) {
                // No data meeting business rule; nothing to publish
                return;
            }
            // Sort descending by Edition (highest Edition first)
            qualifyingBooks.sort(new BookSortByEdition());
            // Guard against very large payloads (prevents event publish failures)
            if (qualifyingBooks.size() > MAX_BOOKS_TO_PUBLISH) {
                // Manual limiting avoids relying on List.subList differences across API versions
                List<Map<String, Object>> limited = new List<Map<String, Object>>();
                for (Integer i = 0; i < MAX_BOOKS_TO_PUBLISH; i++) {
                    limited.add(qualifyingBooks[i]);
                }
                qualifyingBooks = limited;
            }
            publishBooks(qualifyingBooks);
        } catch (System.CalloutException ce) {
            // Network / endpoint / timeout issues
            logException(ce);
        } catch (System.JSONException je) {
            // Malformed / unexpected JSON structure
            logException(je);
        } catch (Exception e) {
            // Catch-all for any other runtime problems
            logException(e);
        }
    }

    /* =============================
       Private Helpers
       ============================= */
    /**
     * Build and send the HTTP request using provided metadata.
     * @param apiDetail configuration metadata (endpoint, method, timeout)
     * @return HttpResponse from remote service (may throw CalloutException)
     */
    private static HttpResponse performCallout(API_Detail__mdt apiDetail) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(apiDetail.Http_Endpoint__c);
        req.setMethod(apiDetail.Http_Method__c);
        if (apiDetail.Http_Timeout__c != null) {
            req.setTimeout(Integer.valueOf(apiDetail.Http_Timeout__c));
        }
        Http http = new Http();
        return http.send(req);
    }

    /**
     * Lightweight success predicate (narrow: only 200 + non-blank body).
     * Can be generalized later to accept other 2xx codes if API broadens.
     */
    private static Boolean isSuccessResponse(HttpResponse res) {
        return (res != null && res.getStatusCode() == HTTP_SUCCESS && String.isNotBlank(res.getBody()));
    }

    /**
     * Deserialize response and collect only those book map entries whose Edition field exceeds threshold.
     * Expected JSON shape (simplified):
     * [ { "Books": [ { "Edition": 601234, ...}, ... ] }, ... ]
     */
    private static List<Map<String, Object>> extractQualifyingBooks(String rawJson) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        if (String.isBlank(rawJson)) {
            return results;
        }
        Object deserialized = JSON.deserializeUntyped(rawJson);
        // Expecting a top-level LIST (according to original implementation). Guard alternatives.
        if (!(deserialized instanceof List<Object>)) {
            return results;
        }
        for (Object rootEntry : (List<Object>)deserialized) {
            if (!(rootEntry instanceof Map<String, Object>)) {
                continue; // Skip non-object entries
            }
            Map<String, Object> rootMap = (Map<String, Object>)rootEntry;
            if (!rootMap.containsKey(KEY_BOOKS) || rootMap.get(KEY_BOOKS) == null) {
                continue; // No books array
            }
            if (!(rootMap.get(KEY_BOOKS) instanceof List<Object>)) {
                continue; // Malformed structure
            }
            List<Object> bookEntries = (List<Object>)rootMap.get(KEY_BOOKS);
            for (Object bookObj : bookEntries) {
                if (!(bookObj instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> bookMap = (Map<String, Object>)bookObj;
                if (isQualifyingBook(bookMap)) {
                    results.add(bookMap);
                }
            }
        }
        return results;
    }

    /**
     * Business predicate: Edition field must exist, be an Integer, and exceed threshold.
     */
    private static Boolean isQualifyingBook(Map<String, Object> bookMap) {
        if (bookMap == null || !bookMap.containsKey(KEY_EDITION)) {
            return false;
        }
        Object editionVal = bookMap.get(KEY_EDITION);
        if (!(editionVal instanceof Integer)) {
            return false; // Edition not an Integer
        }
        Integer edition = (Integer)editionVal;
        return edition != null && edition > DEFAULT_EDITION_THRESHOLD;
    }

    /**
     * Serialize and publish qualifying books via Platform Event.
     * NOTE: No retry logic; consumer should handle idempotency / downstream failures.
     */
    private static void publishBooks(List<Map<String, Object>> books) {
        if (books == null || books.isEmpty()) {
            return;
        }
        String payload = JSON.serialize(books);
        EventBus.publish(new MostPublishedBooks__e(Books__c = payload));
    }
    /**
     * Persist an exception record to custom object Exception_Log__c for later review.
     * Assumes fields: Error_Message__c (Text), Stack_Trace__c (Long Text), Line_Number__c (Number), Type__c (Text).
     * Enhancement idea: add correlation/request id for tracing multi-step processes.
     */
    private static void logException(Exception ex){
        INSERT new Exception_Log__c(Error_Message__c = ex.getMessage(),
                                    Stack_Trace__c = ex.getStackTraceString(),
                                    Line_Number__c = ex.getLineNumber(),
                                    Type__c=ex.getTypeName());
    }
    /* =============================
       Comparator (Descending Edition, nulls last)
       ============================= */
    /**
     * Comparator: Orders book maps by Edition descending.
     * Null Editions are pushed to the end (treated as least significant).
     */
    private class BookSortByEdition implements System.Comparator<Map<String, Object>> {
        public Integer compare(Map<String, Object> b1, Map<String, Object> b2) {
            Integer e1 = (Integer)(b1 != null ? b1.get(KEY_EDITION) : null);
            Integer e2 = (Integer)(b2 != null ? b2.get(KEY_EDITION) : null);
            if (e1 == e2) return 0;              // Equal (covers both null or identical numbers)
            if (e1 == null) return 1;            // Nulls last (so they appear after real numbers)
            if (e2 == null) return -1;           // Other side null => first precedes
            return (e1 < e2) ? 1 : -1;           // Descending numeric order
        }
    }
}