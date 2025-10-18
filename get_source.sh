#!/bin/bash
set -e

# This script downloads the correct OpenJDK source code as a ZIP file.
# This is faster and avoids git authentication issues in CI environments.

VERSION=$1

if [ "$VERSION" == "8" ]; then
    echo "Downloading OpenJDK 8 source..."
    wget -O openjdk.zip https://github.com/MojoLauncher/openjdk-8-multiarch-osx/archive/refs/heads/master.zip
    # Unzip into a folder named 'openjdk'
    unzip openjdk.zip -d .
    mv openjdk-8-multiarch-osx-master openjdk
elif [ "$VERSION" == "17" ]; then
    echo "Downloading OpenJDK 17 source..."
    wget -O openjdk.zip https://github.com/MojoLauncher/openjdk-17-multiarch/archive/refs/heads/master.zip
    unzip openjdk.zip -d .
    mv openjdk-17-multiarch-master openjdk
elif [ "$VERSION" == "21" ]; then
    echo "Downloading OpenJDK 21 source..."
    wget -O openjdk.zip https://github.com/MojoLauncher/openjdk-21-multiarch/archive/refs/heads/master.zip
    unzip openjdk.zip -d .
    mv openjdk-21-multiarch-master openjdk
else
    echo "Invalid version specified: $VERSION"
    exit 1
fi
