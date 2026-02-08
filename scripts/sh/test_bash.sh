#!/bin/bash
# WEBHOOK_URL=https://event-ai.us-east-1.api.aws/webhook/generic/c8e33a91-41d2-457f-80d5-918fac509034
# SECRET="MY-SECRET"
WEBHOOK_URL="https://event-ai.us-east-1.api.aws/webhook/generic/6a14950d-4556-4b7e-adf5-802fcbdfc614"
SECRET="5oEhntph6fBbuOXX0fC00INRW95OEQj84vBPXOHcDhc="

# Create payload
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
INCIDENT_ID="test-alert-$(date +%s)"

PAYLOAD=$(cat <<EOF
{
"eventType": "incident",
"incidentId": "$INCIDENT_ID",
"action": "created",
"priority": "HIGH",
"title": "Test Alert",
"description": "Test alert description",
"service": "TestService",
"timestamp": "$TIMESTAMP"
}
EOF
)

# Generate HMAC signature
SIGNATURE=$(echo -n "${TIMESTAMP}:${PAYLOAD}" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

# Send webhook
echo "Timestamp: $TIMESTAMP"
echo "Signature: $SIGNATURE"
echo "Payload: $PAYLOAD"
echo ""
curl -v -X POST "$WEBHOOK_URL" \
-H "Content-Type: application/json" \
-H "x-amzn-event-timestamp: $TIMESTAMP" \
-H "x-amzn-event-signature: $SIGNATURE" \
-d "$PAYLOAD"
