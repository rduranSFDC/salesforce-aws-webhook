/**
 * @description Queueable class that performs HMAC-signed HTTP callouts to AWS webhooks.
 *              Handles payload construction, signature generation, and response processing.
 * @author Rodrigo Duran
 * @date    2026-02-03  Initial version for AWS Webhook Service and Queueable
 * 
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
     * @description Execute method called by the Queueable framework
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
            
            // Query the Case record
            Case caseRecord = getCaseRecord(this.recordId);
            
            if (caseRecord == null) {
                throw new AWSWebhookService.AWSWebhookException(
                    'Case not found: ' + this.recordId
                );
            }
            
            // Generate ISO 8601 timestamp
            String timestamp = Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            
            // Build the JSON payload
            String payload = buildPayload(caseRecord, this.eventContext);
            System.debug(LoggingLevel.DEBUG, 'Payload: ' + payload);
            System.debug(LoggingLevel.DEBUG, 'Timestamp: ' + timestamp);
            System.debug(LoggingLevel.DEBUG, 'Secret Key: ' + config.Secret_Key__c);    
            System.debug(LoggingLevel.DEBUG, 'Endpoint: ' + config.Endpoint_Named_Credential__c + config.Webhook_Path__c);
            // Generate HMAC-SHA256 signature
            String signature = generateSignature(timestamp, payload, config.Secret_Key__c);
            System.debug(LoggingLevel.DEBUG, 'Signature: ' + signature);
            // Make the HTTP callout
            HttpResponse response = makeCallout(config, timestamp, signature, payload);
            System.debug(LoggingLevel.DEBUG, 'Response: ' + response.getBody());  
            // Process response
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                isSuccess = true;
                resultMessage = 'Webhook called successfully. Status: ' + response.getStatusCode();
                
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
                               ', Body: ' + response.getBody().left(500);
                System.debug(LoggingLevel.DEBUG, 'Result Message: ' + resultMessage);
            }
            
        } catch (Exception e) {
            isSuccess = false;
            resultMessage = 'Error: ' + e.getMessage();
        }
        
        // Update the Case record with integration result
        updateCaseWithResult(this.recordId, requestId, isSuccess, resultMessage);
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
                Timeout_Milliseconds__c
            FROM AWS_Integration_Setting__mdt
            WHERE DeveloperName = :configName
            LIMIT 1
        ];
        System.debug(LoggingLevel.DEBUG, 'Configurations: ' + configs);
        return configs.isEmpty() ? null : configs[0];
    }
    
    /**
     * @description Query the Case record for the payload
     * @param caseId The Case ID to query
     * @return The Case record or null if not found
     */
    @TestVisible
    private Case getCaseRecord(String caseId) {
        List<Case> cases = [
            SELECT 
                Id,
                CaseNumber,
                Subject,
                Description,
                Status,
                Priority,
                Origin,
                Type,
                ContactId,
                Contact.Name,
                Contact.Email,
                AccountId,
                Account.Name,
                CreatedDate,
                LastModifiedDate,
                OwnerId
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];
        
        return cases.isEmpty() ? null : cases[0];
    }
    
    /**
     * @description Build the JSON payload for the webhook
     * @param caseRecord The Case record to include in the payload
     * @param eventContext The event context (e.g., CaseCreate, CaseUpdate)
     * @return JSON string payload
     */
    @TestVisible
    private String buildPayload(Case caseRecord, String eventContext) {
        Map<String, Object> payload = new Map<String, Object>();
        
        // Event metadata
        payload.put('eventType', eventContext);
        payload.put('eventTimestamp', Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        payload.put('sourceSystem', 'Salesforce');
        payload.put('orgId', UserInfo.getOrganizationId());
        
        // Case data
        Map<String, Object> caseData = new Map<String, Object>();
        caseData.put('id', caseRecord.Id);
        caseData.put('caseNumber', caseRecord.CaseNumber);
        caseData.put('subject', caseRecord.Subject);
        caseData.put('description', caseRecord.Description);
        caseData.put('status', caseRecord.Status);
        caseData.put('priority', caseRecord.Priority);
        caseData.put('origin', caseRecord.Origin);
        caseData.put('type', caseRecord.Type);
        caseData.put('ownerId', caseRecord.OwnerId);
        caseData.put('createdDate', caseRecord.CreatedDate?.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        caseData.put('lastModifiedDate', caseRecord.LastModifiedDate?.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        
        // Contact data if available
        if (caseRecord.ContactId != null) {
            Map<String, Object> contactData = new Map<String, Object>();
            contactData.put('id', caseRecord.ContactId);
            contactData.put('name', caseRecord.Contact?.Name);
            contactData.put('email', caseRecord.Contact?.Email);
            caseData.put('contact', contactData);
        }
        
        // Account data if available
        if (caseRecord.AccountId != null) {
            Map<String, Object> accountData = new Map<String, Object>();
            accountData.put('id', caseRecord.AccountId);
            accountData.put('name', caseRecord.Account?.Name);
            caseData.put('account', accountData);
        }
        
        payload.put('case', caseData);
        
        return JSON.serialize(payload);
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
        // Signature format: HMAC-SHA256(timestamp + ":" + payload, secret)
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
        timeout = Math.max(1, Math.min(timeout, 120000)); // Enforce 1-120000ms range
        request.setTimeout(timeout);
        
        // Set body
        request.setBody(payload);
        
        // Make the callout
        Http http = new Http();
        return http.send(request);
    }
    
    /**
     * @description Update the Case record with integration result
     * @param caseId The Case ID to update
     * @param requestId The AWS request ID if available
     * @param isSuccess Whether the callout was successful
     * @param message Status or error message
     */
    @TestVisible
    private void updateCaseWithResult(String caseId, String requestId, Boolean isSuccess, String message) {
        try {
            String commentBody = '[AWS Webhook Integration - ' + 
                                Datetime.now().format('yyyy-MM-dd HH:mm:ss') + ']\n' +
                                'Status: ' + (isSuccess ? 'Success' : 'Failed') + '\n' +
                                'Message: ' + message.left(500);
            
            if (String.isNotBlank(requestId)) {
                commentBody += '\nRequest ID: ' + requestId;
            }
            
            CaseComment comment = new CaseComment(
                ParentId = caseId,
                CommentBody = commentBody,
                IsPublished = false  
            );
            insert comment;
            
            FeedItem post = new FeedItem(
                ParentId = caseId,
                Body = commentBody
            );
            insert post;
            
            System.debug(LoggingLevel.INFO, 'Created CaseComment and FeedItem for Case ' + caseId);
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to create CaseComment: ' + e.getMessage());
        }
    }
}