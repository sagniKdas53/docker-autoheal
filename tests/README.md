# Docker Autoheal Tests

Docker Compose is used to build and deploy test environment.

test.sh waits on watch-autoheal exit code.

The test stack starts unhealthy containers, then polls Docker restart event counts and a local webhook sink.
The run passes once each watched unhealthy container has at least one restart event, each restarted container appears in the webhook payloads, and the control containers remain at zero.

## Run tests
```
cd tests
./tests.sh
```

## Run tests in CI
```
cd tests
export "AUTOHEAL_CONTAINER_LABEL=autoheal-123456"
./tests.sh "MY_UNIQUE_BUILD_NUMBER_123456"
```

This enables the tests to only restart containers within the test spec by using
unique docker-compose project names and autoheal labels (as long as you replace
123456 by a unique number)
