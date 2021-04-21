#!/bin/bash

VERSION=${1:-v1.7.3}
DOCKER_USER=${2:-rogerfar}

docker buildx build --push --platform linux/arm/v7,linux/arm64/v8,linux/amd64 --tag "${DOCKER_USER}/rdtclient:latest" --tag "${DOCKER_USER}/rdtclient:${VERSION}" . --build-arg VERSION=${VERSION}
