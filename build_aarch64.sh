#!/bin/bash
set -e

# Get Source Code and move into its directory
bash get_source.sh $TARGET_VERSION

# THE FIX: The 'cd openjdk' line is REMOVED from here,
# because get_source.sh now handles it.

echo "Applying patches for Java $TARGET_VERSION..."
git apply ../patches/Jre_${TARGET_VERSION}/*.diff

# Configure the build
bash ./configure \
    --openjdk-target=aarch64-linux-androideabi \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=gcc \
    --with-extra-cflags="-fPIC -Wno-error" \
    --with-extra-cxxflags="-fPIC -Wno-error" \
    --with-extra-ldflags="-Wl,-rpath-link=$JAVA_HOME/jre/lib/aarch64" \
    --with-ndk=$NDK_PATH

# Run the build
make images

# After building, find the created JRE image and package it
cd build/linux-aarch64-release/images
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch64.tar.xz $JRE_FOLDER_NAME
