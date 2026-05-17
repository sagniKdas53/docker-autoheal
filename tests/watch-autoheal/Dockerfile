FROM alpine:3.18

RUN apk add --no-cache bash curl docker-cli jq


WORKDIR /app
COPY . .

ENTRYPOINT ["/app/entrypoint.sh"]
