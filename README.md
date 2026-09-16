# Docker Autoheal

Monitor and restart unhealthy docker containers. 
This functionality was proposed to be included with the addition of `HEALTHCHECK`, however didn't make the cut.
This container is a stand-in till there is native support for `--exit-on-unhealthy` https://github.com/docker/docker/pull/22719.

## Supported tags and Dockerfile links

Images are published to the GitHub Container Registry as
`ghcr.io/sagnikdas53/docker-autoheal`.

- [`latest` (*Dockerfile*)](https://github.com/sagniKdas53/docker-autoheal/blob/main/Dockerfile) - rebuilt on every push to `main`, once the integration suite passes
- Each git tag is published under the same name, e.g. `ghcr.io/sagnikdas53/docker-autoheal:1.1.0`

```bash
docker pull ghcr.io/sagnikdas53/docker-autoheal:latest
```

> There is no scheduled rebuild, so a new image is produced only when this
> repository changes. Push a commit or a tag to pick up base image updates.

## How to use

### 1. Docker CLI
#### UNIX socket passthrough
```bash
docker run -d \
    --name autoheal \
    --restart=always \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    ghcr.io/sagnikdas53/docker-autoheal
```
#### TCP socket 
```bash
docker run -d \
    --name autoheal \
    --restart=always \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -e DOCKER_SOCK=tcp://$HOST:$PORT \
    -v /path/to/certs/:/certs/:ro \
    ghcr.io/sagnikdas53/docker-autoheal
```
#### TCP with mTLS (HTTPS)
```bash
docker run -d \
    --name autoheal \
    --restart=always \
    --tlscacert=/certs/ca.pem \
    --tlscert=/certs/client-cert.pem \
    --tlskey=/certs/client-key.pem \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -e DOCKER_HOST=tcp://$HOST:2376 \
    -e DOCKER_SOCK=tcps://$HOST:2376 \
    -e DOCKER_TLS_VERIFY=1 \
    -v /path/to/certs/:/certs/:ro \
    ghcr.io/sagnikdas53/docker-autoheal
```
The certificates and keys need these names and resides under /certs inside the container:
* ca.pem
* client-cert.pem
* client-key.pem

> See https://docs.docker.com/engine/security/https/ for how to configure TCP with mTLS

### Change Timezone
The image ships `tzdata`, so log timestamps and notification bodies follow `TZ`:
```bash
docker run ... -e TZ=Europe/Berlin
```
Bind-mounting the host's zone also still works:
```bash
docker run ... -v /etc/localtime:/etc/localtime:ro
```

### 2. Use in your container image
Choose one of the three alternatives:

a) Apply the label `autoheal=true` to your container to have it watched;<br/>
b) Set ENV `AUTOHEAL_CONTAINER_LABEL=all` to watch all running containers;<br/>
c) Set ENV `AUTOHEAL_CONTAINER_LABEL` to existing container label that has the value `true`;<br/>

> Note: You must apply `HEALTHCHECK` to your docker images first.<br/>
> See https://docs.docker.com/engine/reference/builder/#healthcheck for details.

#### Docker Compose (example)
```yaml
services:
  app:
    extends:
      file: ${PWD}/services.yml
      service: app
    labels:
      autoheal-app: true

  autoheal:
    deploy:
      replicas: 1
    environment:
      AUTOHEAL_CONTAINER_LABEL: autoheal-app
    image: ghcr.io/sagnikdas53/docker-autoheal:latest
    network_mode: none
    restart: always
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock
```

#### Optional Container Labels
|Label                                 |Description|
| --- | --- |
|`autoheal.stop.timeout=20`            |Per container override for the stop timeout in seconds during restart. Non-numeric values are rejected with a warning and the default is used.|
|`autoheal=false`                      |Opt a container out of healing even when it matches the watch filter. The comparison is case-insensitive, so `false`, `False` and `FALSE` all work.|

## Environment Defaults
|Variable                                |Description|
| --- | --- |
|`AUTOHEAL_CONTAINER_LABEL=autoheal`     |set to existing label name that has the value `true`, or `all` to watch every container|
|`AUTOHEAL_INTERVAL=5`                   |check every 5 seconds|
|`AUTOHEAL_START_PERIOD=0`               |wait 0 seconds before first health check|
|`AUTOHEAL_DEFAULT_STOP_TIMEOUT=10`      |Docker waits max 10 seconds (the Docker default) for a container to stop before killing during restarts (container overridable via label, see above)|
|`AUTOHEAL_ONLY_MONITOR_RUNNING=false`   |All containers monitored by default. Set this to true to only monitor running containers. This will result in Paused containers being ignored.|
|`AUTOHEAL_START_EXITED_CONTAINERS=false`|Also start containers that carry the watch label and are in the `exited` state. Requires a real `AUTOHEAL_CONTAINER_LABEL`; it is refused (with a log line) when the label is `all`, because that would start every stopped container on the host.|
|`AUTOHEAL_NOTIFY_ON_START=false`        |Send one notification when autoheal finishes starting up. Useful for confirming that `WEBHOOK_URL`/`APPRISE_URL` are wired up correctly without having to break a container first.|
|`AUTOHEAL_INCLUDE_HEALTH_OUTPUT=false`  |Append the container's last healthcheck output to the notification, so the alert says *why* the container was unhealthy. Read before the restart, since restarting clears the health log.|
|`AUTOHEAL_HEALTH_OUTPUT_LIMIT=500`      |Maximum number of characters of healthcheck output to include|
|`DOCKER_SOCK=/var/run/docker.sock`      |Unix socket for curl requests to Docker API, or a `tcp://host:port` / `tcps://host:port` endpoint|
|`CURL_TIMEOUT=30`                       |--max-time seconds for curl requests to the Docker API and to webhooks. Must be a positive integer; `0` and other invalid values fall back to 30, since curl treats `--max-time 0` as no timeout at all|
|`WEBHOOK_URL=""`                        |post message to the webhook if a container was restarted (or restart failed)|
|`WEBHOOK_JSON_KEY="content"`            |JSON key the message is sent under, e.g. `content` for Discord, `text` for Slack and Mattermost|
|`APPRISE_URL=""`                        |post the same message to an [Apprise](https://github.com/caronc/apprise-api) notify endpoint as `{"title": ..., "body": ...}`|
|`POST_RESTART_SCRIPT=""`                |command to run after each restart attempt (see the warning below)|
|`TZ=""`                                 |timezone for log timestamps, e.g. `Europe/Berlin`|

Every numeric setting is validated at startup. An unparsable value is reported on
stderr and replaced with its default rather than killing the container on the
first `sleep`.

## Notifications

`WEBHOOK_URL` posts `{"<WEBHOOK_JSON_KEY>": "<message>"}`, which covers Discord,
Slack, Mattermost, Home Assistant and anything else that accepts a single-key
JSON body. Payloads are built with `jq`, so container names and healthcheck
output containing quotes, backslashes or newlines stay valid JSON.

For ntfy, Gotify, Pushover, Telegram, email and roughly a hundred other
services, point `APPRISE_URL` at an [Apprise API](https://github.com/caronc/apprise-api)
instance rather than adding a provider-specific integration here:

```yaml
    environment:
      APPRISE_URL: http://apprise:8000/notify/autoheal
```

Delivery happens in the background so a slow or unreachable endpoint never stalls
the healing loop, and each attempt logs its outcome (transport error or non-2xx
status) instead of failing silently.

Set `AUTOHEAL_NOTIFY_ON_START=true` to get a notification at startup if you want
to verify the configuration end to end.

### `POST_RESTART_SCRIPT`

> **Warning:** `POST_RESTART_SCRIPT` is executed by the shell with the container
> name, short id, state and timeout as arguments. Anyone who can set environment
> variables on this container can therefore run arbitrary commands inside it,
> and this container has access to the Docker socket. Leave it empty unless you
> control the deployment, and keep the script itself inside the image.

## Container health

The image's own `HEALTHCHECK` reads a heartbeat that the daemon stamps after
every completed sweep. A loop that is wedged on an unreachable Docker API is
reported as unhealthy, where the previous `pgrep` check only proved the process
still existed.

Startup failures are explicit too: a missing Docker socket, a socket the
container cannot write to, or an unreachable API each produce a named error
rather than a silent no-op loop.

## Testing (building locally)
```bash
docker buildx build -t autoheal .

docker run -d \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    autoheal
```

The integration suite in [`tests/`](tests/) brings up a compose stack of healthy,
unhealthy and opted-out containers plus a webhook sink, and asserts what was and
was not restarted:

```bash
cd tests && ./tests.sh
```
