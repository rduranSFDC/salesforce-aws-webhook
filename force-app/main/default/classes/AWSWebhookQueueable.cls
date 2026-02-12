/**
 * @description Queueable callout engine that performs HMAC-signed HTTP callouts to AWS webhooks.
 *              Delegates payload construction and response handling to pluggable strategies
 *              configured via Custom Metadata (Payload_Builder_Class__c, Response_Handler_Class__c).
 * @author Rodrigo Duran
 * @date   2026-02-03  Initial version
 * @date   2026-02-07  Refactored to Strategy Pattern for multi-service support
 */
public class AWSWebhookQueueable implements Queueable, Database.AllowsCallouts {
    
    private static final String CALLOUT_PREFIX = 'callout:';
    private static final String CONTENT_TYPE_JSON = 'application/json';
    private static final String HEADER_CONTENT_TYPE = 'Content-Type';
    private static final String HEADER_TIMESTAMP = 'x-amzn-event-timestamp';
    private static final String HEADER_SIGNATURE = 'x-amzn-event-signature';
    
    private String recordId;
    private String eventContext;
    private String configurationName;
    
    /**
     * @description Constructor for the queueable job
     * @param recordId The Case or record ID to process
     * @param eventContext The event context (e.g., CaseCreate, CaseUpdate)
     * @param configurationName The Custom Metadata DeveloperName for configuration
     */
    public AWSWebhookQueueable(String recordId, String eventContext, String configurationName) {
        this.recordId = recordId;
        this.eventContext = eventContext;
        this.configurationName = configurationName;
    }
    
    /**
     * @description Execute method called by the Queueable framework.
     *              Orchestrates: config lookup -> payload building -> signing -> callout -> response handling
     * @param context The QueueableContext provided by the system
     */
    public void execute(QueueableContext context) {
        String requestId = null;
        Boolean isSuccess = false;
        String resultMessage = '';
        
        try {
            // Query configuration from Custom Metadata
            AWS_Integration_Setting__mdt config = getConfiguration(this.configurationName);
            
            if (config == null) {
                throw new AWSWebhookService.AWSWebhookException(
                    'Configuration not found: ' + this.configurationName
                );
            }
            
            if (!config.Active__c) {
                throw new AWSWebhookService.AWSWebhookException(
                    'Configuration is inactive: ' + this.configurationName
                );
            }
            
            // Dynamically instantiate the payload builder from Custom Metadata
            AWSWebhookPayloadBuilder builder = 
                (AWSWebhookPayloadBuilder) Type.forName(config.Payload_Builder_Class__c).newInstance();
            String payload = builder.buildPayload(this.recordId, this.eventContext);
            
            // Generate ISO 8601 timestamp
            String timestamp = Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            
            // Generate HMAC-SHA256 signature
            String signature = generateSignature(timestamp, payload, config.Secret_Key__c);
            
            // Make the HTTP callout
            HttpResponse response = makeCallout(config, timestamp, signature, payload);
            
            // Process response
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                isSuccess = true;
                resultMessage = 'Webhook called successfully. Status: ' + response.getStatusCode() + 
                    ', \n\nBody: ' + response.getBody() +
                    ', \n\nPayload: ' + payload;
                
                // Try to extract request ID from response
                try {
                    Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                    if (responseBody.containsKey('requestId')) {
                        requestId = String.valueOf(responseBody.get('requestId'));
                    }
                } catch (Exception e) {
                    // Response may not be JSON, continue without request ID
                }
            } else {
                isSuccess = false;
                resultMessage = 'Webhook call failed. Status: ' + response.getStatusCode() + 
                                ', \n\nBody: ' + response.getBody() +
                                ', \n\nPayload: ' + payload;
                System.debug(LoggingLevel.DEBUG, 'Result Message: ' + resultMessage);
            }
            
            // Dynamically instantiate the response handler from Custom Metadata
            AWSWebhookResponseHandler handler = 
                (AWSWebhookResponseHandler) Type.forName(config.Response_Handler_Class__c).newInstance();
            handler.handleResponse(this.recordId, isSuccess, requestId, resultMessage);
            
        } catch (Exception e) {
            isSuccess = false;
            resultMessage = 'Error: ' + e.getMessage();
            // Attempt to log the error even if the main flow failed
            System.debug(LoggingLevel.ERROR, 'AWSWebhookQueueable error: ' + resultMessage);
        }
    }
    
    /**
     * @description Query the Custom Metadata configuration
     * @param configName The DeveloperName of the configuration
     * @return The configuration record or null if not found
     */
    @TestVisible
    private AWS_Integration_Setting__mdt getConfiguration(String configName) {
        List<AWS_Integration_Setting__mdt> configs = [
            SELECT 
                DeveloperName,
                Endpoint_Named_Credential__c,
                Secret_Key__c,
                Webhook_Path__c,
                Active__c,
                Timeout_Milliseconds__c,
                Payload_Builder_Class__c,
                Response_Handler_Class__c
            FROM AWS_Integration_Setting__mdt
            WHERE DeveloperName = :configName
            LIMIT 1
        ];
        return configs.isEmpty() ? null : configs[0];
    }
    
    /**
     * @description Generate HMAC-SHA256 signature for the request
     * @param timestamp ISO 8601 timestamp
     * @param payload JSON payload string
     * @param secret HMAC secret key
     * @return Base64-encoded signature
     */
    @TestVisible
    private String generateSignature(String timestamp, String payload, String secret) {
        String dataToSign = timestamp + ':' + payload;
        Blob hmacData = Crypto.generateMac(
            'HmacSHA256',
            Blob.valueOf(dataToSign),
            Blob.valueOf(secret)
        );
        return EncodingUtil.base64Encode(hmacData);
    }
    
    /**
     * @description Make the HTTP callout to the AWS webhook
     * @param config The integration configuration
     * @param timestamp ISO 8601 timestamp for the header
     * @param signature HMAC signature for the header
     * @param payload JSON payload body
     * @return HTTP response
     */
    @TestVisible
    private HttpResponse makeCallout(
        AWS_Integration_Setting__mdt config,
        String timestamp,
        String signature,
        String payload
    ) {
        HttpRequest request = new HttpRequest();
        
        // Build the endpoint URL using Named Credential
        String endpoint = CALLOUT_PREFIX + config.Endpoint_Named_Credential__c + config.Webhook_Path__c;
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        
        // Set headers
        request.setHeader(HEADER_CONTENT_TYPE, CONTENT_TYPE_JSON);
        request.setHeader(HEADER_TIMESTAMP, timestamp);
        request.setHeader(HEADER_SIGNATURE, signature);
        
        // Set timeout
        Integer timeout = config.Timeout_Milliseconds__c != null 
            ? Integer.valueOf(config.Timeout_Milliseconds__c) 
            : 30000;
        timeout = Math.max(1, Math.min(timeout, 120000));
        request.setTimeout(timeout);
        
        // Set body
        request.setBody(payload);
        
        // Make the callout
        Http http = new Http();
        return http.send(request);
    }
}
