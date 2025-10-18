#!/bin/bash
set -e

# This script downloads the exact, specific commit of the OpenJDK source code
# that the patches were created for. This is the final and correct method.

VERSION=$1

if [ "$VERSION" == "8" ]; then
    echo "Downloading OpenJDK 8 source (jdk8u) at a specific commit..."
    # This commit is known to work with the jdk8u patches
    git clone https://github.com/openjdk/jdk8u.git openjdk
    cd openjdk
    git checkout 691738743c34
    
elif [ "$VERSION" == "17" ]; then
    echo "Downloading OpenJDK 17 source (jdk17u) at a specific commit..."
    # This commit is known to work with the jdk17u patches
    git clone https://github.com/openjdk/jdk17u.git openjdk
    cd openjdk
    git checkout 92199859ef4a
    
elif [ "$VERSION" == "21" ]; then
    echo "Downloading OpenJDK 21 source (jdk21u) at a specific commit..."
    # This commit is known to work with the jdk21u patches
    git clone https://github.com/openjdk/jdk21u.git openjdk
    cd openjdk
    git checkout 2596b6a37213

else
    echo "Invalid version specified: $VERSION"
    exit 1
fi
