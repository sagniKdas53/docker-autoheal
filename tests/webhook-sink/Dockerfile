FROM python:3.12-alpine

WORKDIR /app
COPY server.py /app/server.py

# Autoheal's startup notification races this server's bind(), so compose gates
# the autoheal service on this check rather than on the container merely
# existing. Polled fast because the whole suite runs on a stopwatch.
HEALTHCHECK --interval=1s --timeout=2s --start-period=1s --retries=30 \
    CMD ["python", "-c", "import socket; socket.create_connection(('127.0.0.1', 8080), 1).close()"]

ENTRYPOINT ["python", "/app/server.py"]
