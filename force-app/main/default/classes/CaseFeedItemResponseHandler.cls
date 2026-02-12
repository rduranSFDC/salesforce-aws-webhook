/**
 * @description Response handler that creates a FeedItem on a Case record
 *              with the webhook integration result. Visible in the Lightning
 *              Case Feed timeline.
 * @author Rodrigo Duran
 * @date   2026-02-07
 */
public class CaseFeedItemResponseHandler implements AWSWebhookResponseHandler {
    
    /**
     * @description Create a FeedItem on the Case with the callout result
     * @param recordId The Case ID to post the FeedItem to
     * @param isSuccess Whether the callout was successful
     * @param requestId The AWS request ID if available (may be null)
     * @param message Status or error message
     */
    public void handleResponse(Id recordId, Boolean isSuccess, String requestId, String message) {
        try {
            String commentBody = '<b>AWS Webhook Integration</b> - ' + 
                                Datetime.now().format('yyyy-MM-dd HH:mm:ss') + '<br/>' +
                                '<b>Status:</b> ' + (isSuccess ? 'Success' : 'Failed') + '<br/>' +
                                '<b>Message:</b> ' + message;
            
            if (String.isNotBlank(requestId)) {
                commentBody += '<br/><b>Request ID:</b> ' + requestId;
            }
            
            FeedItem post = new FeedItem(
                ParentId = recordId,
                Body = commentBody,
                Type = 'TextPost'
            );
            insert post;
            
            System.debug(LoggingLevel.INFO, 'Created FeedItem for record ' + recordId);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create FeedItem: ' + e.getMessage());
        }
    }
}
