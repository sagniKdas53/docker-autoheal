FROM alpine:3.18

RUN apk add --no-cache bash docker-cli


WORKDIR /app
COPY . .

ENTRYPOINT ["/app/entrypoint.sh"]
