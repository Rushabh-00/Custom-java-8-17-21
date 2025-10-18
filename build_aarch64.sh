#!/bin/bash
set -e

# This script builds for 64-bit ARM (arm64-v8a)

# Get Source Code
bash get_source.sh $TARGET_VERSION
cd openjdk

# --- THE CRITICAL STEP: APPLY OUR LOCAL PATCHES ---
echo "Applying patches for Java $TARGET_VERSION..."
# Use git apply to apply all .diff files from the correct patch directory
git apply ../jre_${TARGET_VERSION}/*.diff

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
