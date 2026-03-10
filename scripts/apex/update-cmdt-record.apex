// Update the AWS_DevOps_Agent Custom Metadata record with the new class names
// Note: Custom Metadata records cannot be updated via DML in Apex in a standard context.
// However, we can use the Metadata.Operations API to deploy the update.

Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
customMetadata.fullName = 'AWS_Integration_Setting__mdt.AWS_DevOps_Agent';
customMetadata.label = 'AWS DevOps Agent';

// We need to preserve existing values, but we can't query them directly into a Metadata object.
// So we'll query the record first to get the values.
AWS_Integration_Setting__mdt record = [
    SELECT Endpoint_Named_Credential__c, Secret_Key__c, Webhook_Path__c, Active__c, Timeout_Milliseconds__c
    FROM AWS_Integration_Setting__mdt
    WHERE DeveloperName = 'AWS_DevOps_Agent'
    LIMIT 1
];

Metadata.CustomMetadataValue endpointField = new Metadata.CustomMetadataValue();
endpointField.field = 'Endpoint_Named_Credential__c';
endpointField.value = record.Endpoint_Named_Credential__c;
customMetadata.values.add(endpointField);

Metadata.CustomMetadataValue secretField = new Metadata.CustomMetadataValue();
secretField.field = 'Secret_Key__c';
secretField.value = record.Secret_Key__c;
customMetadata.values.add(secretField);

Metadata.CustomMetadataValue pathField = new Metadata.CustomMetadataValue();
pathField.field = 'Webhook_Path__c';
pathField.value = record.Webhook_Path__c;
customMetadata.values.add(pathField);

Metadata.CustomMetadataValue activeField = new Metadata.CustomMetadataValue();
activeField.field = 'Active__c';
activeField.value = record.Active__c;
customMetadata.values.add(activeField);

Metadata.CustomMetadataValue timeoutField = new Metadata.CustomMetadataValue();
timeoutField.field = 'Timeout_Milliseconds__c';
timeoutField.value = record.Timeout_Milliseconds__c;
customMetadata.values.add(timeoutField);

// Add the new fields
Metadata.CustomMetadataValue builderField = new Metadata.CustomMetadataValue();
builderField.field = 'Payload_Builder_Class__c';
builderField.value = 'AWSDevOpsAgentPayloadBuilder';
customMetadata.values.add(builderField);

Metadata.CustomMetadataValue handlerField = new Metadata.CustomMetadataValue();
handlerField.field = 'Response_Handler_Class__c';
handlerField.value = 'CaseFeedItemResponseHandler';
customMetadata.values.add(handlerField);

Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
mdContainer.addMetadata(customMetadata);

// Enqueue the deployment
// Note: In anonymous Apex, we can't implement the callback interface, so we pass null.
Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, null);
System.debug('Enqueued metadata deployment job: ' + jobId);
