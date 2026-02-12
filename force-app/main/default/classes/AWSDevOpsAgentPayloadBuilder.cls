/**
 * @description Payload builder for the AWS DevOps Agent service.
 *              Queries a Case record and builds an incident-style JSON payload
 *              with instructions for the DevOps Agent to investigate and create
 *              a FeedItem with root cause findings.
 * @author Rodrigo Duran
 * @date   2026-02-07
 */
public class AWSDevOpsAgentPayloadBuilder implements AWSWebhookPayloadBuilder {
    
    /**
     * @description Build the incident payload for the DevOps Agent webhook
     * @param recordId The Case ID to process
     * @param eventContext The event context (e.g., CaseCreate, ManualTrigger)
     * @return Serialized JSON string payload
     */
    public String buildPayload(Id recordId, String eventContext) {
        Case caseRecord = getCaseRecord(recordId);
        
        if (caseRecord == null) {
            throw new AWSWebhookService.AWSWebhookException(
                'Case not found: ' + recordId
            );
        }
        
        Map<String, Object> payload = new Map<String, Object>();
        
        // Top-level incident fields
        payload.put('eventType', 'incident');
        payload.put('incidentId', 'SF-CASE-' + caseRecord.CaseNumber + '-' + Datetime.now().format('yyyyMMddHHmm'));
        payload.put('action', 'created');
        payload.put('priority', 'HIGH');
        payload.put('title', 'Salesforce Case ' + caseRecord.CaseNumber + ' - Analyze and Update');
        payload.put('description', 'Your PRIMARY TASK is to add a Feedback record to Salesforce case ' + caseRecord.CaseNumber + 
                                   ' with root cause findings. To do this: First, investigate case ' + caseRecord.CaseNumber + 
                                   ' to determine the root cause. Second, create a FeedItem record for case ' + caseRecord.CaseNumber + 
                                   ' with your findings. The FeedItem must have Type=\'TextPost\' and ParentId set to the Case Id. ' + 
                                   'Use the Body field for your root cause analysis. Before you write the final investigation summary, you MUST ALWAYS update the Salesforce case with details of your investigation. ' + 
                                   'Double check that the case is updated before you write the final investigation.');
        payload.put('timestamp', Datetime.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        
        return JSON.serialize(payload);
    }
    
    /**
     * @description Query the Case record for the payload
     * @param caseId The Case ID to query
     * @return The Case record or null if not found
     */
    @TestVisible
    private Case getCaseRecord(Id caseId) {
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
}
