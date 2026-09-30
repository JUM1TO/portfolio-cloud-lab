#!/bin/bash

set -Eeuo pipefail

REPO="/opt/portfolio/portfolio-cloud-lab"
IMAGE="jumito-portfolio"
CONTAINER="jumito-portfolio"
CANDIDATE_CONTAINER="jumito-portfolio-candidate"

cd "$REPO"

REVISION="$(git rev-parse --short HEAD)"
NEW_IMAGE="${IMAGE}:${REVISION}"

echo "Deploying revision: ${REVISION}"

echo "Building Docker image..."
docker build -t "$NEW_IMAGE" .

echo "Starting candidate container..."

docker rm -f "$CANDIDATE_CONTAINER" 2>/dev/null || true

docker run -d \
  --name "$CANDIDATE_CONTAINER" \
  -p 127.0.0.1:8081:80 \
  "$NEW_IMAGE"

echo "Validating candidate..."

for i in {1..20}; do
  if curl -fsS http://127.0.0.1:8081 > /dev/null; then
    echo "Candidate is healthy."
    break
  fi

  if [ "$i" -eq 20 ]; then
    echo "Candidate failed health validation."
    docker logs "$CANDIDATE_CONTAINER" || true
    docker rm -f "$CANDIDATE_CONTAINER" || true
    exit 1
  fi

  sleep 1
done

OLD_IMAGE=""

if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  OLD_IMAGE="$(docker inspect --format='{{.Image}}' "$CONTAINER")"
fi

echo "Promoting candidate..."

docker rm -f "$CANDIDATE_CONTAINER"

docker rm -f "$CONTAINER" 2>/dev/null || true

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p 127.0.0.1:8080:80 \
  "$NEW_IMAGE"

echo "Validating production container..."

for i in {1..20}; do
  if curl -fsS http://127.0.0.1:8080 > /dev/null; then
    echo "Production container is healthy."

    docker tag "$NEW_IMAGE" "${IMAGE}:latest"

    echo "Deployment successful: ${REVISION}"
    exit 0
  fi

  sleep 1
done

echo "Production validation failed."

docker logs "$CONTAINER" || true
docker rm -f "$CONTAINER" || true

if [ -n "$OLD_IMAGE" ]; then
  echo "Rolling back previous image..."

  docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p 127.0.0.1:8080:80 \
    "$OLD_IMAGE"
fi

exit 1