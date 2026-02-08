#!/bin/bash

# Configuration
WEBHOOK_URL="https://event-ai.us-east-1.api.aws/webhook/generic/6a14950d-4556-4b7e-adf5-802fcbdfc614"
SECRET="5oEhntph6fBbuOXX0fC00INRW95OEQj84vBPXOHcDhc="

# Parse command line arguments
INCIDENT_ID="${1:-test-alert-$(date +%s)}"
ACTION="${2:-created}"
PRIORITY="${3:-HIGH}"
TITLE="${4:-Test Alert}"
DESCRIPTION="${5:-Test alert description}"
SERVICE="${6:-TestService}"

# Show usage if --help
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 [incident-id] [action] [priority] [title] [description] [service]"
    echo ""
    echo "Parameters:"
    echo "  incident-id  : Unique incident ID (default: test-alert-<timestamp>)"
    echo "  action       : created|updated|closed|resolved (default: created)"
    echo "  priority     : CRITICAL|HIGH|MEDIUM|LOW|MINIMAL (default: HIGH)"
    echo "  title        : Incident title (default: Test Alert)"
    echo "  description  : Incident description (default: Test alert description)"
    echo "  service      : Service name (default: TestService)"
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 INC-001 created CRITICAL \"API Down\" \"Production API is down\""
    echo "  $0 INC-001 updated HIGH \"API Recovering\""
    exit 0
fi

# Create timestamp first
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Create payload - must be compact JSON (no newlines) for HMAC signature
PAYLOAD=$(cat <<EOF | jq -c .
{
"eventType": "incident",
"incidentId": "$INCIDENT_ID",
"action": "$ACTION",
"priority": "$PRIORITY",
"title": "$TITLE",
"description": "$DESCRIPTION",
"service": "$SERVICE",
"timestamp": "$TIMESTAMP"
}
EOF
)

# Generate HMAC signature
# Use the secret as-is (do NOT base64 decode it)
SIGNATURE=$(echo -n "${TIMESTAMP}:${PAYLOAD}" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)

# Display request details
echo "=========================================="
echo "Sending DevOps Agent Webhook Event"
echo "=========================================="
echo "Incident ID: $INCIDENT_ID"
echo "Action: $ACTION"
echo "Priority: $PRIORITY"
echo "Title: $TITLE"
echo "Timestamp: $TIMESTAMP"
echo "Signature: ${SIGNATURE:0:40}..."
echo ""
echo "Payload (compact):"
echo "$PAYLOAD"
echo ""
echo "Payload (formatted):"
echo "$PAYLOAD" | jq . 2>/dev/null || echo "$PAYLOAD"
echo ""
echo "Message to sign:"
echo "${TIMESTAMP}:${PAYLOAD}" | head -c 100
echo "..."
echo ""
echo "=========================================="
echo ""

# Send webhook
curl -X POST "$WEBHOOK_URL" \
-H "Content-Type: application/json" \
-H "x-amzn-event-timestamp: $TIMESTAMP" \
-H "x-amzn-event-signature: $SIGNATURE" \
-d "$PAYLOAD" \
-w "\n\nHTTP Status: %{http_code}\n"

echo ""
echo "=========================================="
echo "Request complete"
echo "=========================================="
