#!/bin/bash
set -e

# This script downloads the correct OpenJDK source code based on the official repositories
# used by MojoLauncher's own build process.

VERSION=$1

if [ "$VERSION" == "8" ]; then
    echo "Downloading OpenJDK 8 source (jdk8u)..."
    # We use the main jdk8u repository which contains the necessary build configurations.
    git clone --depth 1 https://github.com/openjdk/jdk8u.git openjdk
    
elif [ "$VERSION" == "17" ]; then
    echo "Downloading OpenJDK 17 source (jdk17u)..."
    # Clone the specific jdk17u repository.
    git clone --depth 1 https://github.com/openjdk/jdk17u.git openjdk
    
elif [ "$VERSION" == "21" ]; then
    echo "Downloading OpenJDK 21 source (jdk21u)..."
    # Clone the specific jdk21u repository. The branch is handled by the build script itself.
    git clone --depth 1 https://github.com/openjdk/jdk21u.git openjdk
    
else
    echo "Invalid version specified: $VERSION"
    exit 1
fi
