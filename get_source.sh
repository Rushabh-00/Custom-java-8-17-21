#!/bin/bash
set -e

# This script downloads the correct OpenJDK source code based on the official repositories
# and logic you provided from the original build scripts.

VERSION=$1

if [ "$VERSION" == "8" ]; then
    echo "Cloning OpenJDK 8 source (jdk8u)..."
    # This is the standard, correct repository for Android builds.
    git clone --depth 1 https://github.com/openjdk/jdk8u.git openjdk

elif [ "$VERSION" == "17" ]; then
    echo "Cloning OpenJDK 17 source (jdk17u)..."
    # Clones into a directory named 'openjdk-17'
    git clone --depth 1 https://github.com/openjdk/jdk17u.git openjdk-17
    # Rename for consistency with the next build steps
    mv openjdk-17 openjdk

elif [ "$VERSION" == "21" ]; then
    echo "Cloning OpenJDK 21 source (jdk21u)..."
    # Clones the specific branch into a directory named 'openjdk-21'
    # NOTE: The branch might be jdk-21.0.1, we will see if the build fails. This is from your script.
    git clone --branch jdk21.0.1 --depth 1 https://github.com/openjdk/jdk21u.git openjdk-21
    # Rename for consistency with the next build steps
    mv openjdk-21 openjdk
    
else
    echo "Invalid version specified: $VERSION"
    exit 1
fi

echo "Successfully cloned source code into 'openjdk' directory."
