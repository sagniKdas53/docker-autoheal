# Status Update

## Fixed

- The integration test path was moved from legacy docker-compose to docker compose, so the checked-in test command works on
    current Docker setups.
- CI now runs the integration suite before any image publish: the release workflow's build job depends on a test job, so a
    failing suite blocks the push to GHCR.
- The GitHub Actions workflows were moved to current action versions (checkout@v4, setup-qemu@v3, setup-buildx@v3,
    login@v3, metadata-action@v5, build-push-action@v6).
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
- The main README now points at ghcr.io/sagnikdas53/docker-autoheal instead of the upstream Docker Hub image, and no longer
    claims a daily build that no longer exists.

## Still Not Fixed

- The autoheal=False opt-out behavior is still case-sensitive in docker-entrypoint:184. autoheal=false is not treated as
    disabled. That was the remaining review finding we did not change.
- The README no longer documents an image this repository does not publish, but it is still a light edit of the upstream
    text rather than a rewrite for this fork.
