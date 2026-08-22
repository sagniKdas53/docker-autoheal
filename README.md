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
If you need the timezone to match the local machine, you can map the `/etc/localtime` into the container.
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
|`autoheal.stop.timeout=20`            |Per containers override for stop timeout seconds during restart|
| --- | --- |

## Environment Defaults
|Variable                              |Description|
| --- | --- |
|`AUTOHEAL_CONTAINER_LABEL=autoheal`   |set to existing label name that has the value `true`|
|`AUTOHEAL_INTERVAL=5`                 |check every 5 seconds|
|`AUTOHEAL_START_PERIOD=0`             |wait 0 seconds before first health check|
|`AUTOHEAL_DEFAULT_STOP_TIMEOUT=10`    |Docker waits max 10 seconds (the Docker default) for a container to stop before killing during restarts (container overridable via label, see below)|
|`AUTOHEAL_ONLY_MONITOR_RUNNING=false` |All containers monitored by default. Set this to true to only monitor running containers. This will result in Paused contaners being ignored.|
|`DOCKER_SOCK=/var/run/docker.sock`    |Unix socket for curl requests to Docker API|
|`CURL_TIMEOUT=30`                     |--max-time seconds for curl requests to the Docker API and to webhooks. Must be a positive integer; `0` and other invalid values fall back to 30, since curl treats `--max-time 0` as no timeout at all|
|`WEBHOOK_URL=""`                      |post message to the webhook if a container was restarted (or restart failed)|

## Testing (building locally)
```bash
docker buildx build -t autoheal .

docker run -d \
    -e AUTOHEAL_CONTAINER_LABEL=all \
    -v /var/run/docker.sock:/var/run/docker.sock \
    autoheal
```
