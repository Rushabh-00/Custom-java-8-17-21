#!/bin/bash
set -e

VERSION=$1

if [ "$VERSION" == "8" ]; then
    git clone --depth 1 https://github.com/openjdk/jdk8u.git openjdk
elif [ "$VERSION" == "17" ]; then
    git clone --depth 1 https://github.com/openjdk/jdk17u.git openjdk-17
    mv openjdk-17 openjdk
elif [ "$VERSION" == "21" ]; then
    git clone --branch jdk21.0.1 --depth 1 https://github.com/openjdk/jdk21u.git openjdk-21
    mv openjdk-21 openjdk
else
    echo "Invalid version specified: $VERSION"
    exit 1
fi
