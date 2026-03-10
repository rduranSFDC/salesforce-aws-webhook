/**
 * Anonymous Apex script to verify the AWS Integration configuration
 * Run this using: sf apex run --file scripts/apex/verify-aws-config.apex
 */

System.debug('=== Checking AWS Integration Configuration ===');
System.debug('');

// Query all AWS Integration Settings
List<AWS_Integration_Setting__mdt> configs = [
    SELECT 
        DeveloperName,
        MasterLabel,
        Endpoint_Named_Credential__c,
        Secret_Key__c,
        Webhook_Path__c,
        Active__c,
        Timeout_Milliseconds__c,
        Payload_Builder_Class__c,
        Response_Handler_Class__c
    FROM AWS_Integration_Setting__mdt
];

if (configs.isEmpty()) {
    System.debug('ERROR: No AWS_Integration_Setting__mdt records found!');
    System.debug('Please create a Custom Metadata record in Setup > Custom Metadata Types > AWS Integration Setting');
} else {
    System.debug('Found ' + configs.size() + ' configuration(s):');
    System.debug('');
    
    for (AWS_Integration_Setting__mdt config : configs) {
        System.debug('--- Configuration: ' + config.DeveloperName + ' ---');
        System.debug('Label: ' + config.MasterLabel);
        System.debug('Named Credential: ' + config.Endpoint_Named_Credential__c);
        System.debug('Webhook Path: ' + config.Webhook_Path__c);
        System.debug('Active: ' + config.Active__c);
        System.debug('Timeout (ms): ' + config.Timeout_Milliseconds__c);
        System.debug('Payload Builder: ' + config.Payload_Builder_Class__c);
        System.debug('Response Handler: ' + config.Response_Handler_Class__c);
        System.debug('Secret Key: ' + (String.isNotBlank(config.Secret_Key__c) ? '***configured***' : 'NOT SET'));
        System.debug('');
        
        // Validation checks
        List<String> issues = new List<String>();
        
        if (String.isBlank(config.Endpoint_Named_Credential__c)) {
            issues.add('Missing Endpoint Named Credential');
        }
        if (String.isBlank(config.Secret_Key__c)) {
            issues.add('Missing Secret Key');
        }
        if (String.isBlank(config.Webhook_Path__c)) {
            issues.add('Missing Webhook Path');
        }
        if (!config.Active__c) {
            issues.add('Configuration is INACTIVE');
        }
        if (String.isBlank(config.Payload_Builder_Class__c)) {
            issues.add('Missing Payload Builder Class');
        }
        if (String.isBlank(config.Response_Handler_Class__c)) {
            issues.add('Missing Response Handler Class');
        }
        
        if (!issues.isEmpty()) {
            System.debug('WARNINGS:');
            for (String issue : issues) {
                System.debug('  - ' + issue);
            }
        } else {
            System.debug('Configuration looks good!');
        }
        System.debug('');
    }
}

System.debug('=== Configuration Check Complete ===');
