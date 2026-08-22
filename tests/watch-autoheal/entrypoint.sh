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

# Docker does not increment .RestartCount for explicit restart API calls, so the
# daemon's restart event stream is the reliable source for these tests. The dump
# is fetched once per poll and every assertion matches against that snapshot.
fetch_restart_events() {
  local now
  local since

  now=$(date +%s)
  since=$((now - 300))

  docker events \
    --since "$since" \
    --until "$now" \
    --filter type=container \
    --filter event=restart \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
    --format '{{json .Actor.Attributes}}'
}

restart_events_or_die() {
  local events

  if ! events=$(fetch_restart_events); then
    echo "ERR: Failed to query docker restart events for project ${COMPOSE_PROJECT_NAME}" >&2
    exit 1
  fi

  printf '%s\n' "$events"
}

restart_event_count_for_service() {
  local service="$1"
  local events="$2"

  # The caller has already established that the query succeeded, so a zero here
  # genuinely means "no restarts" rather than "the query failed".
  grep -c "\"com.docker.compose.service\":\"${service}\"" <<<"$events" || true
}

webhook_sink_container() {
  local ids

  if ! ids=$(docker ps -q \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME}" \
    --filter "label=com.docker.compose.service=webhook-sink"); then
    echo "ERR: Failed to query the webhook-sink container for project ${COMPOSE_PROJECT_NAME}" >&2
    return 1
  fi

  if [[ -z "$ids" ]]; then
    echo "ERR: No running webhook-sink container for project ${COMPOSE_PROJECT_NAME}" >&2
    return 1
  fi

  printf '%s\n' "${ids%%$'\n'*}"
}

webhook_logs() {
  local id
  local logs

  id=$(webhook_sink_container) || return 1

  if ! logs=$(docker logs "$id" 2>&1); then
    echo "ERR: Failed to read logs from webhook-sink container ${id}" >&2
    return 1
  fi

  printf '%s\n' "$logs"
}

webhook_logs_or_die() {
  local logs

  logs=$(webhook_logs) || exit 1

  printf '%s\n' "$logs"
}

webhook_request_count() {
  local logs="$1"

  # The sink prints one line per request, and every notification body carries
  # this phrase exactly once, so this counts requests rather than log lines.
  grep -c "found to be unhealthy" <<<"$logs" || true
}

webhook_reports_successful_restart() {
  local target="$1"
  local logs="$2"
  local line

  # Both halves must appear on the same line: the "Failed to restart" payload
  # also contains the container name, and must not satisfy this assertion.
  while IFS= read -r line; do
    if [[ "$line" == *"$target"* && "$line" == *"Successfully restarted the container!"* ]]; then
      return 0
    fi
  done <<<"$logs"

  return 1
}

print_restart_event_counts() {
  local service
  local events

  events=$(fetch_restart_events) || return 0

  for service in "${expected_restart_services[@]}" "${unexpected_restart_services[@]}"; do
    echo "$service restart events: $(restart_event_count_for_service "$service" "$events")"
  done
}

print_webhook_logs() {
  echo "webhook logs:"
  webhook_logs || true
}

deadline=$((SECONDS + 60))

while (( SECONDS < deadline )); do
  expected_restarts_met=true
  expected_webhooks_met=true

  restart_events=$(restart_events_or_die)
  sink_logs=$(webhook_logs_or_die)

  for service in "${expected_restart_services[@]}"; do
    count=$(restart_event_count_for_service "$service" "$restart_events")
    echo "$service restart events: $count"

    if (( count < 1 )); then
      expected_restarts_met=false
    fi
  done

  request_count=$(webhook_request_count "$sink_logs")
  echo "webhook request count: $request_count"

  for target in "${expected_webhook_targets[@]}"; do
    if ! webhook_reports_successful_restart "$target" "$sink_logs"; then
      expected_webhooks_met=false
    fi
  done

  for service in "${unexpected_restart_services[@]}"; do
    count=$(restart_event_count_for_service "$service" "$restart_events")
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
