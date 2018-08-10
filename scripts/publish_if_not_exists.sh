#!/bin/sh
set -e

VERSION=$(cat package.json | jq -r '.version')
NAME=@dydxprotocol/protocol

test -z "$(npm info $NAME@$VERSION)"
if [ $? -eq 0 ]
then
    mkdir -p ~/.ssh
    touch ~/.ssh/known_hosts
    ssh-keyscan -H github.com >> ~/.ssh/known_hosts
    git config --global user.email "ci@dydx.exchange"
    git config --global user.name "circle_ci"

    # Get version and tag
    git tag v${VERSION}
    git push --tags

    npm publish
else
    echo "skipping publish, package $NAME@$VERSION already published"
fi
