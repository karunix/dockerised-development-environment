#!/usr/bin/env bash

if [[ -f .env ]]; then 
  echo Sourcing environment variables from .env
  source .env
fi

if [[ -z $VERSION ]]; then
  echo 'VERSION has not been set, cannot continue'
  exit 1
fi

if [[ -z $USER_NAME ]]; then
  USER_NAME=$(id -u)
fi

docker build --build-arg user=${USER_NAME} -t birchwoodlangham/dockerised-development-environment:${VERSION} .
docker tag birchwoodlangham/dockerised-development-environment:${VERSION} birchwoodlangham/dockerised-development-environment:latest
