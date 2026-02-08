/**
 * @description Invocable service for triggering AWS Webhook callouts from Flow and Agentforce.
 *              Enqueues async jobs to make HMAC-signed HTTP callouts to AWS endpoints.
 * @author Rodrigo Duran
 * @date    2026-02-03  Initial version for AWS Webhook Service and Queueable
 * 
 */
public with sharing class AWSWebhookService {
    
    /**
     * @description Input wrapper for the invocable method
     */
    public class WebhookRequest {
        @InvocableVariable(label='Record ID' description='The Case or record ID to process' required=true)
        public String recordId;
        
        @InvocableVariable(label='Context' description='Event context such as CaseCreate or CaseUpdate' required=true)
        public String context;
        
        @InvocableVariable(label='Configuration Name' description='Custom Metadata DeveloperName, defaults to AWS_DevOps_Agent' required=false)
        public String configurationName;
    }
    
    /**
     * @description Output wrapper for the invocable method
     */
    public class WebhookResult {
        @InvocableVariable(label='Success' description='Whether the job was enqueued successfully')
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Status message or error details')
        public String message;
        
        @InvocableVariable(label='Job ID' description='Async job ID for tracking')
        public String jobId;
    }
    
    /**
     * @description Invocable method to trigger AWS webhook callout
     * @param requests List of webhook requests from Flow
     * @return List of results with job status
     */
    @InvocableMethod(label='Trigger AWS Webhook' 
                     description='Enqueues an async job to call AWS webhook with HMAC signature' 
                     category='Integration')
    public static List<WebhookResult> triggerWebhook(List<WebhookRequest> requests) {
        List<WebhookResult> results = new List<WebhookResult>();
        
        for (WebhookRequest request : requests) {
            WebhookResult result = new WebhookResult();
            
            try {
                // Validate required inputs
                if (String.isBlank(request.recordId)) {
                    throw new AWSWebhookException('Record ID is required');
                }
                if (String.isBlank(request.context)) {
                    throw new AWSWebhookException('Context is required');
                }
                
                // Default configuration name if not provided: AWS_DevOps_Agent
                String configName = String.isNotBlank(request.configurationName) 
                    ? request.configurationName 
                    : 'AWS_DevOps_Agent';
                
                // Enqueue the queueable job
                AWSWebhookQueueable queueableJob = new AWSWebhookQueueable(
                    request.recordId,
                    request.context,
                    configName
                );
                
                Id jobId = System.enqueueJob(queueableJob);
                
                result.isSuccess = true;
                result.message = 'Webhook job enqueued successfully';
                result.jobId = jobId;
                
            } catch (Exception e) {
                result.isSuccess = false;
                result.message = e.getMessage();
                result.jobId = null;
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    /**
     * @description Custom exception for AWS Webhook errors
     */
    public class AWSWebhookException extends Exception {}
}