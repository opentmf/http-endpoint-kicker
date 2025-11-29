#!/bin/sh
set -eu

VERSION_FILE="/app/VERSION"
VERSION="dev"
if [ -r "$VERSION_FILE" ]; then
  VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "dev")
fi

# ========================
# Config
# ========================

# Full URL of the endpoint to trigger (required)
: "${TRIGGER_URL:?TRIGGER_URL is required}"

# HTTP method (optional, default POST)
TRIGGER_METHOD="${TRIGGER_METHOD:-POST}"

# Token script path for Bearer auth (optional)
# If unset or empty -> no Bearer token is used.
TOKEN_SCRIPT_PATH="${TOKEN_SCRIPT_PATH:-}"

# Optional body (inline or from file)
TRIGGER_BODY="${TRIGGER_BODY:-}"
TRIGGER_BODY_FILE="${TRIGGER_BODY_FILE:-}"
TRIGGER_CONTENT_TYPE="${TRIGGER_CONTENT_TYPE:-application/json}"

# Optional extra headers (multi-line string, one header per line)
TRIGGER_EXTRA_HEADERS="${TRIGGER_EXTRA_HEADERS:-}"

# Basic auth (optional). If either is set, we treat it as a Basic-auth config.
BASIC_AUTH_USERNAME="${BASIC_AUTH_USERNAME:-}"
BASIC_AUTH_PASSWORD="${BASIC_AUTH_PASSWORD:-}"

# ========================
# Helpers
# ========================

log() {
  # Log to stderr; token never printed
  printf '%s %s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)" "$*" >&2
}

# ========================
# Auth header selection
# ========================

build_auth_header() {
  # Decide which auth mode to use and echo the header, or empty if none.
  # Priority:
  #   1. Basic auth if BASIC_AUTH_* present
  #   2. Bearer auth if TOKEN_SCRIPT_PATH set
  #   3. No auth otherwise

  if [ -n "$BASIC_AUTH_USERNAME" ] || [ -n "$BASIC_AUTH_PASSWORD" ]; then
    # Basic auth selected
    if [ -n "$TOKEN_SCRIPT_PATH" ]; then
      log "Configuration error: BASIC_AUTH_* and TOKEN_SCRIPT_PATH both set. Please choose either Basic or Bearer auth."
      exit 1
    fi

    if [ -z "$BASIC_AUTH_USERNAME" ] || [ -z "$BASIC_AUTH_PASSWORD" ]; then
      log "Configuration error: both BASIC_AUTH_USERNAME and BASIC_AUTH_PASSWORD must be set for Basic auth."
      exit 1
    fi

    credentials="${BASIC_AUTH_USERNAME}:${BASIC_AUTH_PASSWORD}"
    # Encode to base64; strip newlines just in case
    basic_token=$(printf '%s' "$credentials" | base64 | tr -d '\n')
    printf '%s' "Authorization: Basic $basic_token"
    return 0
  fi

  if [ -n "$TOKEN_SCRIPT_PATH" ]; then
    if [ ! -x "$TOKEN_SCRIPT_PATH" ]; then
      log "Token script '$TOKEN_SCRIPT_PATH' not found or not executable."
      exit 1
    fi

    log "Invoking token script: $TOKEN_SCRIPT_PATH"

    token=$("$TOKEN_SCRIPT_PATH") || {
      rc=$?
      log "Token script failed with exit code $rc."
      exit "$rc"
    }

    if [ -z "$token" ]; then
      log "Token script returned an empty token."
      exit 1
    fi

    printf '%s' "Authorization: Bearer $token"
    return 0
  fi

  # No auth configured
  printf '%s' ""
}

# ========================
# Main
# ========================

main() {
  # Support `--version` / `-v`
  if [ "${1-}" = "--version" ] || [ "${1-}" = "-v" ]; then
    printf 'http-endpoint-kicker %s\n' "$VERSION"
    exit 0
  fi

  auth_header=$(build_auth_header)

  log "http-endpoint-kicker-${VERSION} Calling HTTP endpoint: $TRIGGER_METHOD $TRIGGER_URL"

  # Build curl arguments safely using "set --"
  set -- -sS -o /tmp/http_endpoint_kicker_response.out -w '%{http_code}' \
    -X "$TRIGGER_METHOD"

  # Auth header, if any
  if [ -n "$auth_header" ]; then
    set -- "$@" -H "$auth_header"
  fi

  # Content-Type header, if provided
  if [ -n "$TRIGGER_CONTENT_TYPE" ]; then
    set -- "$@" -H "Content-Type: $TRIGGER_CONTENT_TYPE"
  fi

  # Extra headers (one per line)
  if [ -n "$TRIGGER_EXTRA_HEADERS" ]; then
    old_IFS=$IFS
    IFS='
'
    for h in $TRIGGER_EXTRA_HEADERS; do
      # skip empty lines
      if [ -n "$h" ]; then
        set -- "$@" -H "$h"
      fi
    done
    IFS=$old_IFS
  fi

  # Body: file has precedence over inline
  if [ -n "$TRIGGER_BODY_FILE" ]; then
    if [ ! -f "$TRIGGER_BODY_FILE" ]; then
      log "TRIGGER_BODY_FILE '$TRIGGER_BODY_FILE' does not exist."
      exit 1
    fi
    set -- "$@" --data-binary @"$TRIGGER_BODY_FILE"
  elif [ -n "$TRIGGER_BODY" ]; then
    set -- "$@" --data-binary "$TRIGGER_BODY"
  fi

  # Finally, add URL
  set -- "$@" "$TRIGGER_URL"

  http_code=$(curl "$@")

  case "$http_code" in
    2??)
      log "HTTP endpoint call succeeded (HTTP $http_code)."
      exit 0
      ;;
    *)
      log "HTTP endpoint call failed (HTTP $http_code). Response body follows:"
      cat /tmp/http_endpoint_kicker_response.out >&2
      exit 1
      ;;
  esac
}

main "$@"
