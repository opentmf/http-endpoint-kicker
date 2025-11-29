FROM alpine:3.22.2

ARG APP_VERSION=dev
LABEL org.opencontainers.image.version=$APP_VERSION

RUN apk add --no-cache curl jq

RUN addgroup -S kicker && adduser -S kicker -G kicker

WORKDIR /app

COPY --chown=kicker:kicker VERSION http-endpoint-kicker.sh get-token-default.sh ./
RUN chmod +x http-endpoint-kicker.sh get-token-default.sh

USER kicker

ENTRYPOINT ["/app/http-endpoint-kicker.sh"]
