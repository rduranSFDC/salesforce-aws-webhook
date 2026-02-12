/**
 * @description Interface for building webhook payloads. Each service implements
 *              this interface to define its own JSON payload structure.
 *              Implementations are responsible for their own SOQL queries.
 * @author Rodrigo Duran
 * @date   2026-02-07
 */
public interface AWSWebhookPayloadBuilder {
    /**
     * @description Build the JSON payload for the webhook callout
     * @param recordId The source record ID (e.g., Case Id)
     * @param eventContext The event context (e.g., CaseCreate, ManualTrigger)
     * @return Serialized JSON string payload
     */
    String buildPayload(Id recordId, String eventContext);
}
