#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:?}"
BUILD_NUMBER="${BUILD_NUMBER:?}"
CONTEXT_PATH="${CONTEXT_PATH:-.}"
PLATFORMS="${PLATFORMS:-linux/amd64}"
PUSH="${PUSH:-false}"
REGISTRY_URL="${REGISTRY_URL:-docker.io}"
REGISTRY_USERNAME="${REGISTRY_USERNAME:-}"
REGISTRY_TOKEN="${REGISTRY_TOKEN:-}"

TAG="${IMAGE_NAME}:${BUILD_NUMBER}"
REMOTE_TAG="$REGISTRY_URL/$IMAGE_NAME:${BUILD_NUMBER}"

SET_LATEST=$([[ "$BUILD_NUMBER" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]] && echo "true" || echo "false")

if [[ "$PUSH" == "true" ]]; then
  if [[ -z "$REGISTRY_URL" || -z "$REGISTRY_USERNAME" || -z "$REGISTRY_TOKEN" ]]; then
    echo "Missing registry credentials (URL, username, or token)."
    exit 1
  fi
  echo "Logging into $REGISTRY_URL..."
  echo "$REGISTRY_TOKEN" | docker login "$REGISTRY_URL" -u "$REGISTRY_USERNAME" --password-stdin
fi

docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

docker buildx create --name builder --use
docker buildx inspect --bootstrap

docker buildx build \
  --platform "$PLATFORMS" \
  -t "$TAG" \
  $( [[ "$SET_LATEST" == "true" ]] && echo "-t latest") \
  "$CONTEXT_PATH" \
  $( [[ "$PUSH" == "true" ]] && echo "--push" )

echo "Build completed successfully!"
if [[ "$PUSH" == "true" ]]; then
  echo "Pushed to: $REMOTE_TAG"
else
  echo "Local image: $TAG"
fi
