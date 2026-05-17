# Status Update

## Fixed

- The integration test path was moved from legacy docker-compose to docker compose, so the checked-in test command works on
    current Docker setups.
- CI now runs the integration suite before any image publish, so broken test paths no longer go unnoticed.
- GitHub Actions no longer runs daily; it runs on PRs and code pushes that touch the relevant files.
- Image publishing was moved from the upstream Docker Hub namespace to your GHCR namespace:
    ghcr.io/sagnikdas53/docker-autoheal.
- Webhook and Apprise notifications now use bounded background curl calls with CURL_TIMEOUT, so notification workers cannot
    hang indefinitely.
- The integration suite now verifies restart behavior using unhealthy containers plus control containers that must not
    restart.
- The integration suite also verifies webhook delivery through a local webhook sink and fails if restart notifications are
    not emitted.
- The test harness cleanup was tightened with merged compose files and --remove-orphans, so the stack is torn down more
    reliably.

## Still Not Fixed

- The autoheal=False opt-out behavior is still case-sensitive in docker-entrypoint:158. autoheal=false is not treated as
    disabled. That was the remaining review finding we did not change.
- The GitHub Actions workflow still uses older action versions like actions/checkout@v2 and docker/build-push-action@v2. It
    works, but upgrading them would be sensible maintenance rather than a functional fix.
- The README has not been fully updated to reflect all of the new CI and webhook test behavior. The test README was updated,
    but the main project docs still lag behind the current setup.
