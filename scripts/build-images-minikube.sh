#!/usr/bin/env bash
# Build images from sibling repos and load them into the current Minikube cluster.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECTS="$(cd "$ROOT/.." && pwd)"
TAG="${IMAGE_TAG:-1.0.0}"

eval "$(minikube docker-env)"

docker build -t "api-pulse-auth-service:${TAG}" "$PROJECTS/api-pulse-auth-service"
docker build -t "api-pulse-analytics-service:${TAG}" "$PROJECTS/api-pulse-analytics-service"
docker build -t "api-pulse-web:${TAG}" "$PROJECTS/api-pulse-web"

echo "Images tagged :${TAG} are available in Minikube's Docker daemon."
