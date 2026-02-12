/**
 * @description Interface for handling webhook callout responses. Each service implements
 *              this interface to define its own post-callout behavior (e.g., create a
 *              FeedItem, update a record, fire a Platform Event, or just log).
 * @author Rodrigo Duran
 * @date   2026-02-07
 */
public interface AWSWebhookResponseHandler {
    /**
     * @description Handle the result of a webhook callout
     * @param recordId The source record ID (e.g., Case Id)
     * @param isSuccess Whether the callout was successful
     * @param requestId The AWS request ID if available (may be null)
     * @param message Status or error message
     */
    void handleResponse(Id recordId, Boolean isSuccess, String requestId, String message);
}
