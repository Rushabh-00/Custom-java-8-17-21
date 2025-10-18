#!/bin/bash
set -e

# This script downloads the correct OpenJDK source code based on the version we want to build.

VERSION=$1

if [ "$VERSION" == "8" ]; then
    echo "Downloading OpenJDK 8 source..."
    git clone --depth=1 https://github.com/MojoLauncher/openjdk-8-multiarch-osx.git openjdk
elif [ "$VERSION" == "17" ]; then
    echo "Downloading OpenJDK 17 source..."
    git clone --depth=1 https://github.com/MojoLauncher/openjdk-17-multiarch.git openjdk
elif [ "$VERSION" == "21" ]; then
    echo "Downloading OpenJDK 21 source..."
    git clone --depth=1 https://github.com/MojoLauncher/openjdk-21-multiarch.git openjdk
else
    echo "Invalid version specified: $VERSION"
    exit 1
fi
