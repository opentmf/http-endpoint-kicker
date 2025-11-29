# http-endpoint-kicker

A tiny, opinionated Docker image that:

1. (Optionally) gets an access token.
2. Makes **exactly one** configurable HTTP request.
3. Exits with `0` on success (2xx), non-zero otherwise.

Designed to be used from **Kubernetes CronJobs**, CI pipelines, or any environment that can run a container.

Current released version: `1.0.0` (see [VERSION](VERSION) and git tags).

<!-- TOC -->
* [http-endpoint-kicker](#http-endpoint-kicker)
  * [Features](#features)
  * [Quick start](#quick-start)
    * [1. No auth (public endpoint)](#1-no-auth-public-endpoint)
    * [2. Bearer token auth (client_credentials) via OIDC/OAuth2](#2-bearer-token-auth-client_credentials-via-oidcoauth2)
    * [3. Bearer token auth (password) via OIDC/OAuth2](#3-bearer-token-auth-password-via-oidcoauth2)
    * [4. Basic auth](#4-basic-auth)
    * [5. Sending a JSON body](#5-sending-a-json-body)
      * [Inline:](#inline)
      * [From file (e.g. mounted ConfigMap/Secret):](#from-file-eg-mounted-configmapsecret)
  * [Environment Variables](#environment-variables)
  * [Custom Token Scripts](#custom-token-scripts)
  * [Kubernetes Example](#kubernetes-example)
  * [Building locally](#building-locally)
  * [CI: Multi-Arch Builds](#ci-multi-arch-builds)
  * [License](#license)
<!-- TOC -->

## Features

- **Single HTTP request per run** – simple and predictable.
- **Authentication modes**:
    - No auth
    - **Bearer token** via pluggable token script
    - **Basic auth**
- **Request customization**:
    - HTTP method (`TRIGGER_METHOD`)
    - Optional body (`TRIGGER_BODY` / `TRIGGER_BODY_FILE`)
    - Content-Type (`TRIGGER_CONTENT_TYPE`)
    - Extra headers (`TRIGGER_EXTRA_HEADERS`)
- **Pluggable token acquisition**:
    - Built-in script: OIDC/OAuth2, supports `client_credentials` and `password` grants.
    - Or plug your own script via `TOKEN_SCRIPT_PATH`.

---

## Quick start

### 1. No auth (public endpoint)

```bash
docker run --rm \
  -e TRIGGER_URL="https://example.com/api/ping" \
  -e TRIGGER_METHOD=GET \
  ghcr.io/opentmf/http-endpoint-kicker:1.0.0
```

### 2. Bearer token auth (client_credentials) via OIDC/OAuth2
```bash
docker run --rm \
  -e TRIGGER_URL="https://my-service/processing/process" \
  -e TRIGGER_METHOD=POST \
  -e TOKEN_SCRIPT_PATH="/app/get-token-default.sh" \
  -e OIDC_TOKEN_URL="https://idp/realms/myrealm/protocol/openid-connect/token" \
  -e OIDC_CLIENT_ID="my-client" \
  -e OIDC_CLIENT_SECRET="my-secret" \
  ghcr.io/opentmf/http-endpoint-kicker:1.0.0
```

### 3. Bearer token auth (password) via OIDC/OAuth2
```bash
docker run --rm \
  -e TRIGGER_URL="https://my-service/processing/process" \
  -e TRIGGER_METHOD=POST \
  -e TOKEN_SCRIPT_PATH="/app/get-token-default.sh" \
  -e OIDC_TOKEN_URL="https://idp/realms/myrealm/protocol/openid-connect/token" \
  -e OIDC_CLIENT_ID="my-client" \
  -e OIDC_CLIENT_SECRET="my-secret" \
  -e OIDC_GRANT_TYPE="password" \
  -e OIDC_USERNAME="my-username" \
  -e OIDC_PASSWORD="my-password" \
  ghcr.io/opentmf/http-endpoint-kicker:1.0.0
```

### 4. Basic auth
```bash
docker run --rm \
  -e TRIGGER_URL="https://my-service/internal/trigger" \
  -e TRIGGER_METHOD=POST \
  -e BASIC_AUTH_USERNAME="kicker" \
  -e BASIC_AUTH_PASSWORD="s3cr3t" \
  ghcr.io/opentmf/http-endpoint-kicker:1.0.0
```

### 5. Sending a JSON body

#### Inline:
```bash
docker run --rm \
  -e TRIGGER_URL="https://example.com/api/jobs" \
  -e TRIGGER_METHOD=POST \
  -e TRIGGER_CONTENT_TYPE="application/json" \
  -e TRIGGER_BODY='{"action":"start"}' \
  ghcr.io/opentmf/http-endpoint-kicker:1.0.0
```

#### From file (e.g. mounted ConfigMap/Secret):
```bash
docker run --rm \
  -e TRIGGER_URL="https://example.com/api/jobs" \
  -e TRIGGER_METHOD=POST \
  -e TRIGGER_CONTENT_TYPE="application/json" \
  -e TRIGGER_BODY_FILE="/data/body.json" \
  -v "$PWD/body.json":/data/body.json:ro \
  ghcr.io/opentmf/http-endpoint-kicker:1.0.0
```

## Environment Variables

| Type       | Variable                | Required    | Default Value      | Description                                                                                                              |
|------------|-------------------------|-------------|--------------------|--------------------------------------------------------------------------------------------------------------------------|
| **Core**   | `TRIGGER_URL`           | Yes         |                    | Full URL of the endpoint to call.                                                                                        |
|            | `TRIGGER_METHOD`        | No          | POST               | Any method accepted by curl (e.g., GET, POST, PUT, DELETE).                                                              |
|            | `TRIGGER_EXTRA_HEADERS` | No          |                    | Optional `Key: Value` pairs as a linefeed (\n) delimited string. Key id the desired header name.                         |
| **Body**   | `TRIGGER_BODY`          | No          |                    | Inline request body (string). Useful for small JSON payloads.                                                            |
|            | `TRIGGER_BODY_FILE`     | No          |                    | Path to a file inside the container; contents will be sent as the request body. If both are set, TRIGGER_BODY_FILE wins. |
|            | `TRIGGER_CONTENT_TYPE`  | No          | application/json   | Sets the Content-Type header (e.g., application/json, application/x-www-form-urlencoded).                                |
| **Auth**   | `BASIC_AUTH_USERNAME`   | If Basic    |                    | Basic auth username, if basic auth is to be used                                                                         |
|            | `BASIC_AUTH_PASSWORD`   | If Basic    |                    | Basic auth password, if basic auth is to be used                                                                         |
| **Bearer** | `TOKEN_SCRIPT_PATH`     | If Bearer   |                    | Path to the getToken script for Bearer auth. Specify /epp/get-token-default.sh or your own script.                       |
|            | `OIDC_TOKEN_URL`        | If Bearer   |                    | The full URL to obtain an OIDC access token. Example: https://keycloak/auth/realms/xyz/protocol/openid-connect/token     |
|            | `OIDC_CLIENT_ID`        | If Bearer   |                    | The OIDC client_id                                                                                                       |
|            | `OIDC_CLIENT_SECRET`    | If Bearer   |                    | The OIDC client_secret                                                                                                   |
|            | `OIDC_GRANT_TYPE`       | No          | client_credentials | Either `client_credentials` (the default if not set) or `password`                                                       |
|            | `OIDC_SCOPE`            | No          | openid             | The necessary OIDC scope. Defaults to `openid` if not set.                                                               |
|            | `OIDC_USERNAME`         | If password |                    | The username for the `password` grant type                                                                               |
|            | `OIDC_PASSWORD`         | If password |                    | The password for the `password` grant type                                                                               |


## Custom Token Scripts

It is possible to provide a custom token script. Inside the docker image, `curl` and `jq` is provided. 

If you provide your own script:

**1. Must be executable** inside the container.
```bash
chmod +x my-token.sh

docker run ... \
  -v "$PWD/my-token.sh":/opt/my-token.sh:ro \  # mount your script as a volume
  -e TOKEN_SCRIPT_PATH=/opt/my-token.sh \      # instruct the container to use your script
  ...
```
**2. On Success**
- Print only the raw token to stdout (no quotes, no extra text).
- Return exit code `0`.

**3. On Failure**
- You may write error details to stderr; they’ll appear in container logs.
- Return a non-zero exit code.

**Example Minimal Script**
```bash
#!/bin/sh
set -eu

# implement your custom logic here
token="my-static-token-123"

# print only the token
printf '%s' "$token"
```

## Kubernetes Example
See [k8s/cronjob-example.yaml](k8s/cronjob-example.yaml) for a full example.

## Building locally
```bash
# first build a local docker image
docker build -t local/http-endpoint-kicker:test .

# then a minimal example to run it locally
docker run --rm \
  -e TRIGGER_URL="https://example.com/health" \
  -e TRIGGER_METHOD=GET \
  local/http-endpoint-kicker:test
```

## CI: Multi-Arch Builds
This repo includes a GitHub Actions workflow that:
- Builds for linux/amd64 and linux/arm64
- Pushes to ghcr.io/opentmf/http-endpoint-kicker on git tags like 1.0.0

## License
This project uses Apache License v2.0. You can [click here](LICENSE) for the license text.
