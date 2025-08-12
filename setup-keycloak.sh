#!/bin/bash
# setup_keycloak.sh - Configure Keycloak for the todo app (runs inside container via docker exec)

set -e

# Load environment variables from .env file
if [ -f .env ]; then
  source .env
else
  echo "Error: .env file not found"
  exit 1
fi

# Validate required environment variables
: "${KEYCLOAK_CONTAINER_NAME:?Error: KEYCLOAK_CONTAINER_NAME not set}"
: "${KEYCLOAK_URL:?Error: KEYCLOAK_URL not set}"
: "${ADMIN_USER:?Error: ADMIN_USER not set}"
: "${ADMIN_PASS:?Error: ADMIN_PASS not set}"
: "${REALM_NAME:?Error: REALM_NAME not set}"
: "${CLIENT_ID:?Error: CLIENT_ID not set}"
: "${CLIENT_SECRET:?Error: CLIENT_SECRET not set}"
: "${REDIRECT_URIS:?Error: REDIRECT_URIS not set}"
: "${TEST_USER:?Error: TEST_USER not set}"
: "${TEST_PASS:?Error: TEST_PASS not set}"

# Helper to run kcadm inside container
kc() {
  docker exec -i "$KEYCLOAK_CONTAINER_NAME" /opt/keycloak/bin/kcadm.sh "$@"
}

# Wait for Keycloak to be ready (checks serverinfo endpoint inside container)
echo "Waiting for Keycloak to be ready..."
for i in {1..24}; do
    if kc get serverinfo --server http://localhost:8080 --realm master --user "$ADMIN_USER" --password "$ADMIN_PASS" >/dev/null 2>&1; then
        echo "Keycloak is ready!"
        break
    fi
    echo "Keycloak not ready, retrying in 5 seconds..."
    sleep 5
    if [ $i -eq 24 ]; then
        echo "Error: Keycloak did not become ready after 120 seconds"
        docker logs "$KEYCLOAK_CONTAINER_NAME"
        exit 1
    fi
done

echo "Logging in as Keycloak admin..."
kc config credentials --server http://localhost:8080 --realm master \
  --user "$ADMIN_USER" --password "$ADMIN_PASS"

echo "Creating realm: $REALM_NAME..."
if ! kc get realms/$REALM_NAME >/dev/null 2>&1; then
  kc create realms -s realm="$REALM_NAME" -s enabled=true
else
  echo "Realm $REALM_NAME already exists."
fi

echo "Creating client: $CLIENT_ID..."
if ! kc get clients -r "$REALM_NAME" --fields clientId | grep -q "\"$CLIENT_ID\""; then
  kc create clients -r "$REALM_NAME" \
    -s clientId="$CLIENT_ID" \
    -s enabled=true \
    -s publicClient=false \
    -s "redirectUris=[\"$REDIRECT_URIS\"]" \
    -s directAccessGrantsEnabled=true
  # Now set secret after creation
  CLIENT_UUID=$(kc get clients -r "$REALM_NAME" -q clientId="$CLIENT_ID" --fields id | grep '"id"' | sed 's/.*"id" : "\([^"]*\)".*/\1/')
  kc update clients/$CLIENT_UUID -r "$REALM_NAME" -s secret="$CLIENT_SECRET"
else
  echo "Client $CLIENT_ID already exists."
fi

echo "Creating test user..."
if ! kc get users -r "$REALM_NAME" -q username="$TEST_USER" | grep -q "$TEST_USER"; then
  kc create users -r "$REALM_NAME" \
    -s username="$TEST_USER" \
    -s enabled=true \
    -s emailVerified=true \
    -s email="$TEST_USER@example.com"
  echo "Setting password for new user $TEST_USER..."
  USER_ID=$(kc get users -r "$REALM_NAME" -q username="$TEST_USER" --fields id | grep '"id"' | sed 's/.*"id" : "\([^"]*\)".*/\1/')
  kc set-password -r "$REALM_NAME" --userid "$USER_ID" --new-password "$TEST_PASS"
  # Ensure user is fully set up - update all required fields
  kc update users/"$USER_ID" -r "$REALM_NAME" \
    -s emailVerified=true \
    -s enabled=true \
    -s firstName="Test" \
    -s lastName="User"
else
  echo "User $TEST_USER already exists."
  echo "Resetting password for $TEST_USER..."
  USER_ID=$(kc get users -r "$REALM_NAME" -q username="$TEST_USER" --fields id | grep '"id"' | sed 's/.*"id" : "\([^"]*\)".*/\1/')
  kc set-password -r "$REALM_NAME" --userid "$USER_ID" --new-password "$TEST_PASS"
  # Ensure user is fully set up - update all required fields
  kc update users/"$USER_ID" -r "$REALM_NAME" \
    -s emailVerified=true \
    -s enabled=true \
    -s firstName="Test" \
    -s lastName="User" \
    -s email="$TEST_USER@example.com"
fi

echo "Keycloak setup complete."