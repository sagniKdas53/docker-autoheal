# Status Update

## Fixed in this round (from upstream willfarrell/docker-autoheal issues and PRs)

- `autoheal=false` now actually opts a container out. The exclusion only ever
  compared against the capitalised `"False"`, so the documented lower-case form
  silently did nothing (upstream issue #153). The comparison is case-insensitive
  and the integration suite has a container that would have caught it.
- `WEBHOOK_JSON_KEY` defaults to `content` in the entrypoint, matching the
  Dockerfile's `ENV` instead of contradicting it with `text` (upstream #152).
- Notification payloads are built with `jq` instead of string interpolation, so
  a container name or healthcheck output containing a quote, backslash or
  newline no longer produces invalid JSON that the receiver drops.
- The SIGTERM trap no longer runs `kill $$`, which re-delivered the signal to
  the shell from inside its own handler and showed up as a segfault in the host
  syslog (upstream PR #131). Shutdown is also immediate now instead of waiting
  out `AUTOHEAL_INTERVAL`, and SIGINT is handled too.
- A Docker socket that exists but is not writable is reported by name at
  startup. It used to produce a silent loop that restarted nothing and said
  nothing (upstream PR #146). An unreachable API is logged as well.
- A transient Docker API error no longer takes the daemon down through
  `set -e`: the response is validated, the failure is logged, and the next
  sweep retries.
- Every numeric setting (`AUTOHEAL_INTERVAL`, `AUTOHEAL_START_PERIOD`,
  `AUTOHEAL_DEFAULT_STOP_TIMEOUT`, `CURL_TIMEOUT`) is validated instead of
  failing later with a bare shell error, and a malformed
  `autoheal.stop.timeout` label can no longer reach the Docker API query
  string.
- `AUTOHEAL_ONLY_MONITOR_RUNNING` accepts the usual spellings (`True`, `yes`,
  `1`) rather than only the literal `false`, and is declared in the Dockerfile
  alongside the other settings.
- The container `HEALTHCHECK` reads a heartbeat stamped after each sweep.
  `pgrep -f autoheal` only proved the process existed, so a loop wedged on an
  unreachable API still reported healthy.
- Alpine moved from 3.18 (end-of-life May 2025) to 3.22.

## Added from upstream requests

- `tzdata` is installed, so `TZ=` selects a zone without bind-mounting
  `/etc/localtime` (upstream #143).
- `AUTOHEAL_INCLUDE_HEALTH_OUTPUT` appends the last healthcheck output to the
  notification, read before the restart clears it (upstream #81).
- `AUTOHEAL_NOTIFY_ON_START` sends one notification at startup, which is how to
  verify webhook configuration without breaking a container first
  (upstream PR #82, issue #90).
- `AUTOHEAL_START_EXITED_CONTAINERS` starts labelled containers that are in the
  `exited` state (upstream PR #85). Two flaws in that PR are fixed here: the
  query needs `all=true` or it matches nothing, and the feature is refused with
  `AUTOHEAL_CONTAINER_LABEL=all`, which would otherwise start every stopped
  container on the host.
- CI gained a lint job (shellcheck over all three shell scripts, hadolint over
  the Dockerfile) and the release build now depends on it.

## Deliberately not adopted

- ntfy (#107), Pushover (#103) and Gotify (#86) integrations. `APPRISE_URL`
  already covers all three plus roughly a hundred other services; the README now
  says so instead of the repo growing one branch per provider.
- The restart retry queue (PR #102). It rewrites the entrypoint to require bash
  and associative arrays, and an unhealthy container is already retried on the
  next sweep because it is still unhealthy.
- `EXTERNAL_HOSTNAME` (PR #121). Worth revisiting, but it reassigns the variable
  inside the loop so the prefix compounds on every container.

## Still open

- `POST_RESTART_SCRIPT` is arbitrary command execution in a container that holds
  the Docker socket (upstream #135). It is kept for compatibility and the README
  now carries an explicit warning, but it is not sandboxed.
- The README is still largely upstream's text with this fork's specifics edited
  in, rather than a rewrite.
