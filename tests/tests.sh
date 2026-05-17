#!/usr/bin/env bash
set -euxo pipefail

COMPOSE_PROJECT_NAME=${1:-autoheal-test}
export COMPOSE_PROJECT_NAME
COMPOSE=(docker compose)

function cleanup()
{
    exit_status=$?
    echo "exit was $exit_status"
    # stop autoheal first, to stop it restarting the test containers while we try to stop them
    "${COMPOSE[@]}" -f docker-compose.yml stop autoheal || true
    "${COMPOSE[@]}" -f docker-compose.autoheal.yml -f docker-compose.yml down --remove-orphans || true
    exit "$exit_status"
}
trap cleanup EXIT
"${COMPOSE[@]}" -f docker-compose.yml up --build -d
"${COMPOSE[@]}" -f docker-compose.yml -f docker-compose.autoheal.yml up --build --exit-code-from watch-autoheal watch-autoheal
