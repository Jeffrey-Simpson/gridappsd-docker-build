#!/bin/bash

TAG="${TRAVIS_BRANCH//\//_}"

ORG=`echo $DOCKER_PROJECT | tr '[:upper:]' '[:lower:]'`
ORG="${ORG:-gridappsd}"
ORG="${ORG:+${ORG}/}"
IMAGE="${ORG}gridappsd_base"
TIMESTAMP=`date +'%y%m%d%H'`
GITHASH=`git log -1 --pretty=format:"%h"`

BUILD_VERSION="${TIMESTAMP}_${GITHASH}${TRAVIS_BRANCH:+:$TRAVIS_BRANCH}"
echo "BUILD_VERSION $BUILD_VERSION"

trigger_gridappsd_build() {
body='{
  "request": {
  "branch":"$TRAVIS_BRANCH"
}}'

echo " "
echo "Triggering gridappsd build"

curl -s -X POST \
   -H "Content-Type: application/json" \
   -H "Accept: application/json" \
   -H "Travis-API-Version: 3" \
   -H "Authorization: token $BUILD_AUTH_TOKEN" \
   -d "$body" \
   https://api.travis-ci.org/repo/GRIDAPPSD%2FGOSS-GridAPPS-D/requests
}

# Pass gridappsd tag to docker-compose
docker build --no-cache --rm=true --build-arg TIMESTAMP="${BUILD_VERSION}" -f Dockerfile.gridappsd_base -t ${IMAGE}:${TIMESTAMP}_${GITHASH} .
status=$?
if [ $status -ne 0 ]; then
  echo "Error: status $status"
  exit 1
fi

# To have `DOCKER_USERNAME` and `DOCKER_PASSWORD`
# filled you need to either use `travis`' cli
# (https://github.com/travis-ci/travis.rb)
# and then `travis set ..` or go to the travis
# page of your repository and then change the
# environment in the settings pannel.

if [ -n "$DOCKER_USERNAME" -a -n "$DOCKER_PASSWORD" ]; then

  echo " "
  echo "Connecting to docker"

  echo $DOCKER_PASSWORD | docker login -u $DOCKER_USERNAME --password-stdin
  status=$?
  if [ $status -ne 0 ]; then
    echo "Error: status $status"
    exit 1
  fi

  if [ -n "$TAG" -a -n "$ORG" ]; then
    # Get the built container name
    CONTAINER=`docker images --format "{{.Repository}}:{{.Tag}}" ${IMAGE}`

    echo "docker push ${CONTAINER}"
    docker push "${CONTAINER}"
    status=$?
    if [ $status -ne 0 ]; then
      echo "Error: status $status"
      exit 1
    fi

    echo "docker tag ${CONTAINER} ${IMAGE}:$TAG"
    docker tag ${CONTAINER} ${IMAGE}:$TAG
    status=$?
    if [ $status -ne 0 ]; then
      echo "Error: status $status"
      exit 1
    fi

    echo "docker push ${IMAGE}:$TAG"
    docker push ${IMAGE}:$TAG
    status=$?
    if [ $status -ne 0 ]; then
      echo "Error: status $status"
      exit 1
    fi
    trigger_gridappsd_build
  fi

fi

