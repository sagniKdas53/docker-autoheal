# syntax = docker/dockerfile:latest

# Alpine 3.18 reached end-of-life in May 2025 and no longer receives security
# updates for curl/jq, so the floor is a currently supported release.
ARG ALPINE_VERSION=3.22

FROM alpine:${ALPINE_VERSION}

# tzdata lets TZ= select a zone without bind-mounting /etc/localtime from the
# host, so log timestamps and notifications can match local time anywhere.
RUN apk add --no-cache curl jq tzdata

ENV AUTOHEAL_CONTAINER_LABEL=autoheal \
    AUTOHEAL_START_PERIOD=0 \
    AUTOHEAL_INTERVAL=5 \
    AUTOHEAL_DEFAULT_STOP_TIMEOUT=10 \
    AUTOHEAL_ONLY_MONITOR_RUNNING=false \
    AUTOHEAL_START_EXITED_CONTAINERS=false \
    AUTOHEAL_NOTIFY_ON_START=false \
    AUTOHEAL_INCLUDE_HEALTH_OUTPUT=false \
    AUTOHEAL_HEALTH_OUTPUT_LIMIT=500 \
    DOCKER_SOCK=/var/run/docker.sock \
    CURL_TIMEOUT=30 \
    WEBHOOK_URL="" \
    WEBHOOK_JSON_KEY="content" \
    APPRISE_URL="" \
    POST_RESTART_SCRIPT=""

COPY --chmod=0755 docker-entrypoint /

# `pgrep -f autoheal` only proved the process was alive, so a loop wedged on an
# unreachable Docker API still reported healthy. The entrypoint stamps a
# heartbeat after every sweep and this check reads it back.
HEALTHCHECK --interval=30s --timeout=10s --start-period=45s --retries=3 \
    CMD ["/docker-entrypoint", "healthcheck"]

ENTRYPOINT ["/docker-entrypoint"]

CMD ["autoheal"]
