#!/bin/sh
set -eu

# Required env vars
: "${OIDC_TOKEN_URL:?OIDC_TOKEN_URL is required}"
: "${OIDC_CLIENT_ID:?OIDC_CLIENT_ID is required}"
: "${OIDC_CLIENT_SECRET:?OIDC_CLIENT_SECRET is required}"

# Optional / configurable
OIDC_GRANT_TYPE="${OIDC_GRANT_TYPE:-client_credentials}"  # client_credentials | password
OIDC_SCOPE="${OIDC_SCOPE:-openid}"

log() {
  # Log to stderr so stdout remains "pure token"
  printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" >&2
}

case "$OIDC_GRANT_TYPE" in
  client_credentials)
    # No extra fields required
    ;;
  password)
    : "${OIDC_USERNAME:?OIDC_USERNAME is required for password grant}"
    : "${OIDC_PASSWORD:?OIDC_PASSWORD is required for password grant}"
    ;;
  *)
    log "Unsupported OIDC_GRANT_TYPE='$OIDC_GRANT_TYPE'."
    log "Supported by default script: client_credentials, password."
    log "Provide your own token script and set TOKEN_SCRIPT_PATH to use other grant types."
    exit 1
    ;;
esac

log "Requesting access token from IdP using grant_type='${OIDC_GRANT_TYPE}'."

if [ "$OIDC_GRANT_TYPE" = "password" ]; then
  response=$(
    curl -sS -X POST "$OIDC_TOKEN_URL" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "grant_type=${OIDC_GRANT_TYPE}" \
      --data-urlencode "client_id=${OIDC_CLIENT_ID}" \
      --data-urlencode "client_secret=${OIDC_CLIENT_SECRET}" \
      --data-urlencode "username=${OIDC_USERNAME}" \
      --data-urlencode "password=${OIDC_PASSWORD}" \
      ${OIDC_SCOPE:+--data-urlencode "scope=${OIDC_SCOPE}"}
  )
else
  # client_credentials
  response=$(
    curl -sS -X POST "$OIDC_TOKEN_URL" \
      -H 'Content-Type: application/x-www-form-urlencoded' \
      --data-urlencode "grant_type=${OIDC_GRANT_TYPE}" \
      --data-urlencode "client_id=${OIDC_CLIENT_ID}" \
      --data-urlencode "client_secret=${OIDC_CLIENT_SECRET}" \
      ${OIDC_SCOPE:+--data-urlencode "scope=${OIDC_SCOPE}"}
  )
fi

token=$(printf '%s' "$response" | jq -r '.access_token // empty')

if [ -z "$token" ]; then
  log "Failed to extract access_token from response."
  log "Raw response (truncated to 512 chars):"
  printf '%s' "$response" | head -c 512 >&2
  echo >&2
  exit 1
fi

# Print only the token on stdout
printf '%s' "$token"
