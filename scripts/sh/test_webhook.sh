#!/usr/bin/env zsh
set -euo
setopt pipefail

# Defaults (can be overridden via env or args)
WEBHOOK_URL="${WEBHOOK_URL:-https://your-api-gateway.amazonaws.com/webhook/generic/YOUR-UUID}"
SECRET="${SECRET:-YOUR-SECRET-KEY}"
ACTION="created"
PRIORITY="HIGH"
TITLE="Test Alert"
DESCRIPTION="Test alert description"
SERVICE="TestService"
COUNT=1
VERBOSE=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: $0 [-u webhook_url] [-k secret] [-a action] [-p priority] [-t title] [-d description] [-s service] [-n count] [-v] [--dry-run]
  -u  webhook URL (or set WEBHOOK_URL)
  -k  secret for HMAC (or set SECRET)
  -a  action (created|updated|resolved)
  -p  priority (LOW|MEDIUM|HIGH)
  -t  title
  -d  description
  -s  service
  -n  number of events to send
  -v  verbose
  --dry-run  print payload and headers but do not send
EOF
  exit 2
}

# Parse args
while (( $# )); do
  case "$1" in
    -u) WEBHOOK_URL="$2"; shift 2;;
    -k) SECRET="$2"; shift 2;;
    -a) ACTION="$2"; shift 2;;
    -p) PRIORITY="$2"; shift 2;;
    -t) TITLE="$2"; shift 2;;
    -d) DESCRIPTION="$2"; shift 2;;
    -s) SERVICE="$2"; shift 2;;
    -n) COUNT="$2"; shift 2;;
    -v) VERBOSE=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage;;
    *) echo "Unknown arg: $1"; usage;;
  esac
done

# Helpers
compact_json() {
  local raw="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$raw" | jq -c .
  else
    if command -v python3 >/dev/null 2>&1; then
      printf '%s' "$raw" | python3 -c 'import sys,json;print(json.dumps(json.load(sys.stdin)))'
    else
      printf '%s' "$raw" | tr -d '\n' | sed -E 's/ +/ /g'
    fi
  fi
}

send_once() {
  local ts="$1" payload signature http_code respfile
  respfile=$(mktemp 2>/dev/null || mktemp -t test_webhook)
  payload="$2"

  if [ -n "$SECRET" ]; then
    signature=$(printf "%s:%s" "$ts" "$payload" | openssl dgst -sha256 -hmac "$SECRET" -binary | base64)
  else
    signature=""
  fi

  if [ "$VERBOSE" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
    echo "Timestamp: $ts"
    echo "Signature: ${signature:-<none>}"
    echo "Payload: $payload"
    echo ""
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi

  http_code=$(curl -sS -w "%{http_code}" -o "$respfile" -X POST "$WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -H "x-amzn-event-timestamp: $ts" \
    -H "x-amzn-event-signature: $signature" \
    -d "$payload")

  if [ "$VERBOSE" -eq 1 ]; then
    echo "Response body:"
    cat "$respfile" 2>/dev/null || true
  fi

  if (( http_code >= 200 && http_code < 300 )); then
    echo "Sent successfully (HTTP $http_code)" >&2
    rm -f "$respfile"
    return 0
  else
    echo "Failed (HTTP $http_code). Response:" >&2
    cat "$respfile" >&2 || true
    rm -f "$respfile"
    return 1
  fi
}

# Main
for (( i = 1; i <= COUNT; i++ )); do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
  INCIDENT_ID="test-alert-$(date +%s)-$i"

  raw_payload=$(
    cat <<EOF
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

  PAYLOAD=$(compact_json "$raw_payload")
  send_once "$TIMESTAMP" "$PAYLOAD"
done