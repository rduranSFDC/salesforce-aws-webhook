/**
 * Anonymous Apex script to test the AWS Webhook integration
 * Run this using: sf apex run --file scripts/apex/test-aws-webhook.apex
 */

// Step 1: Find an existing Case to use for testing
List<Case> cases = [SELECT Id, CaseNumber, Subject FROM Case LIMIT 1];

if (cases.isEmpty()) {
    System.debug('ERROR: No Case records found in the org. Please create a Case first.');
} else {
    Case testCase = cases[0];
    System.debug('Using Case: ' + testCase.CaseNumber + ' - ' + testCase.Subject);
    System.debug('Case Id: ' + testCase.Id);
    
    // Step 2: Create the webhook request
    AWSWebhookService.WebhookRequest request = new AWSWebhookService.WebhookRequest();
    request.recordId = testCase.Id;
    request.context = 'CaseTest';
    request.configurationName = 'AWS_DevOps_Agent'; // Change this if using a different config name
    
    // Step 3: Trigger the webhook
    System.debug('Triggering AWS Webhook...');
    List<AWSWebhookService.WebhookResult> results = AWSWebhookService.triggerWebhook(
        new List<AWSWebhookService.WebhookRequest>{ request }
    );
    
    // Step 4: Output the results
    for (AWSWebhookService.WebhookResult result : results) {
        System.debug('=== Webhook Result ===');
        System.debug('Success: ' + result.isSuccess);
        System.debug('Message: ' + result.message);
        System.debug('Job ID: ' + result.jobId);
    }
    
    if (results[0].isSuccess) {
        System.debug('');
        System.debug('Queueable job enqueued successfully!');
        System.debug('Check the Apex Jobs page (Setup > Apex Jobs) to see the job status.');
        System.debug('Check Debug Logs for the callout details and response.');
    }
}
