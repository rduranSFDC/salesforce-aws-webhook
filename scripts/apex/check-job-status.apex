/**
 * Anonymous Apex script to check the status of AWS Webhook Queueable jobs
 * Run this using: sf apex run --file scripts/apex/check-job-status.apex
 */

System.debug('=== Checking AWS Webhook Job Status ===');
System.debug('');

// Query recent AsyncApexJob records for our Queueable class
List<AsyncApexJob> jobs = [
    SELECT 
        Id,
        Status,
        JobType,
        ApexClass.Name,
        CreatedDate,
        CompletedDate,
        NumberOfErrors,
        ExtendedStatus,
        MethodName
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'AWSWebhookQueueable'
    ORDER BY CreatedDate DESC
    LIMIT 10
];

if (jobs.isEmpty()) {
    System.debug('No AWSWebhookQueueable jobs found.');
    System.debug('This could mean:');
    System.debug('  1. No webhook has been triggered yet');
    System.debug('  2. The job was triggered more than 7 days ago (jobs are purged)');
} else {
    System.debug('Found ' + jobs.size() + ' recent job(s):');
    System.debug('');
    
    for (AsyncApexJob job : jobs) {
        System.debug('--- Job: ' + job.Id + ' ---');
        System.debug('Status: ' + job.Status);
        System.debug('Created: ' + job.CreatedDate);
        System.debug('Completed: ' + job.CompletedDate);
        System.debug('Errors: ' + job.NumberOfErrors);
        
        if (String.isNotBlank(job.ExtendedStatus)) {
            System.debug('Extended Status: ' + job.ExtendedStatus);
        }
        
        // Interpret status
        if (job.Status == 'Completed') {
            if (job.NumberOfErrors == 0) {
                System.debug('Result: SUCCESS - Job completed without errors');
            } else {
                System.debug('Result: FAILED - Job completed with ' + job.NumberOfErrors + ' error(s)');
            }
        } else if (job.Status == 'Failed') {
            System.debug('Result: FAILED - ' + job.ExtendedStatus);
        } else if (job.Status == 'Queued' || job.Status == 'Preparing' || job.Status == 'Processing') {
            System.debug('Result: IN PROGRESS - Job is still running');
        } else if (job.Status == 'Aborted') {
            System.debug('Result: ABORTED - Job was cancelled');
        }
        
        System.debug('');
    }
}

System.debug('=== Job Status Check Complete ===');
System.debug('');
System.debug('TIP: For detailed execution logs, check:');
System.debug('  1. Setup > Debug Logs (add a trace flag for the Automated Process user)');
System.debug('  2. Setup > Apex Jobs (for job status and errors)');
