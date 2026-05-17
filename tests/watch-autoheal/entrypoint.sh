#!/usr/bin/env bash
set -euo pipefail

expected_restart_services=(
  "should-restart-default-timeout"
  "should-restart-custom-timeout"
)

unexpected_restart_services=(
  "shouldnt-restart-healthy"
  "shouldnt-restart-no-label"
)

expected_webhook_targets=(
  "${COMPOSE_PROJECT_NAME}-should-restart-default-timeout-1"
  "${COMPOSE_PROJECT_NAME}-should-restart-custom-timeout-1"
)

webhook_sink_container="${COMPOSE_PROJECT_NAME}-webhook-sink-1"

restart_event_count_for_service() {
  local now
  local since
  local service="$1"

  now=$(date +%s)
  since=$((now - 300))

  # Docker does not increment .RestartCount for explicit restart API calls, so
  # the daemon's restart event stream is the reliable source for these tests.
  docker events \
    --since "$since" \
    --until "$now" \
    --filter type=container \
    --filter event=restart \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
    --format '{{json .Actor.Attributes}}' | grep -c "\"com.docker.compose.service\":\"${service}\"" || true
}

print_restart_event_counts() {
  local service

  for service in "${expected_restart_services[@]}" "${unexpected_restart_services[@]}"; do
    echo "$service restart events: $(restart_event_count_for_service "$service")"
  done
}

webhook_logs() {
  docker logs "$webhook_sink_container" 2>&1 || true
}

webhook_request_count() {
  webhook_logs | awk 'END { print NR + 0 }'
}

webhook_contains_target() {
  local target="$1"

  webhook_logs | grep -Fq "$target"
}

print_webhook_logs() {
  echo "webhook logs:"
  webhook_logs
}

deadline=$((SECONDS + 60))

while (( SECONDS < deadline )); do
  expected_restarts_met=true
  expected_webhooks_met=true

  for service in "${expected_restart_services[@]}"; do
    count=$(restart_event_count_for_service "$service")
    echo "$service restart events: $count"

    if (( count < 1 )); then
      expected_restarts_met=false
    fi
  done

  request_count=$(webhook_request_count)
  echo "webhook request count: $request_count"

  for target in "${expected_webhook_targets[@]}"; do
    if ! webhook_contains_target "$target"; then
      expected_webhooks_met=false
    fi
  done

  for service in "${unexpected_restart_services[@]}"; do
    count=$(restart_event_count_for_service "$service")
    echo "$service restart events: $count"

    if (( count != 0 )); then
      echo "ERR: No restarts expected on $service" >&2
      exit 1
    fi
  done

  if [[ "$expected_restarts_met" == true && "$expected_webhooks_met" == true ]]; then
    echo "OK: Expected unhealthy containers were restarted and webhook notifications were delivered"
    exit 0
  fi

  sleep 2
done

echo "ERR: Timed out waiting for unhealthy containers to restart or emit webhook notifications" >&2
print_restart_event_counts
print_webhook_logs
exit 1
