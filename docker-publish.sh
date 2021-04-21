#!/bin/bash

VERSION=${1:-1.7.3}

docker buildx build --push --platform linux/arm/v7,linux/arm64/v8,linux/amd64 --tag "ravensorb/rdtclient" . --build-arg VERSION=${VERSION}
