#!/bin/bash

# Define Keycloak container and the health check URL
KEYCLOAK_CONTAINER_NAME="keycloak"
KEYCLOAK_HEALTH_URL="http://keycloak:8080/realms/master"

echo "Starting Keycloak services..."
docker compose --env-file .env -f keycloak-compose.yaml up -d

echo "Waiting for Keycloak realm to be available at ${KEYCLOAK_HEALTH_URL}..."
# The loop will execute the curl command inside the Keycloak container.
# The `until` command continues until `curl` returns a 0 exit code (success).
until docker compose exec "$KEYCLOAK_CONTAINER_NAME" curl -s -f "$KEYCLOAK_HEALTH_URL" > /dev/null; do
  echo "Keycloak realm is not yet ready. Waiting..."
  sleep 5
done

echo "Keycloak realm is up and running. Starting other services."
docker compose --env-file .env -f traefik-compose.yaml up -d

echo "All services are up and running!"