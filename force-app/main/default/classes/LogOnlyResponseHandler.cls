/**
 * @description Lightweight response handler that only writes System.debug logs.
 *              Useful for services that handle their own state externally,
 *              during development, or when no Salesforce record update is needed.
 * @author Rodrigo Duran
 * @date   2026-02-07
 */
public class LogOnlyResponseHandler implements AWSWebhookResponseHandler {
    
    /**
     * @description Log the callout result without creating any records
     * @param recordId The source record ID
     * @param isSuccess Whether the callout was successful
     * @param requestId The AWS request ID if available (may be null)
     * @param message Status or error message
     */
    public void handleResponse(Id recordId, Boolean isSuccess, String requestId, String message) {
        String logPrefix = '[AWS Webhook - ' + Datetime.now().format('yyyy-MM-dd HH:mm:ss') + ']';
        
        if (isSuccess) {
            System.debug(LoggingLevel.INFO, logPrefix + ' SUCCESS for record ' + recordId + 
                 '. Message: ' + message + 
                (String.isNotBlank(requestId) ? '. Request ID: ' + requestId : ''));
        } else {
            System.debug(LoggingLevel.ERROR, logPrefix + ' FAILED for record ' + recordId + 
                '. Message: ' + message);
        }
    }
}
