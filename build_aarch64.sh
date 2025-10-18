#!/bin/bash
set -e

# This script builds for 64-bit ARM (arm64-v8a)

# Get Source Code
bash get_source.sh $TARGET_VERSION
cd openjdk

# Configure the build
bash ./configure \
    --openjdk-target=aarch64-linux-androideabi \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=gcc \
    --with-extra-cflags="-fPIC -Wno-error" \
    --with-extra-cxxflags="-fPIC -Wno-error" \
    --with-extra-ldflags="-Wl,-rpath-link=$JAVA_HOME/jre/lib/aarch64"

# Run the build
make images

# After building, find the created JRE image and package it
cd build/linux-aarch64-release/images
# The folder is named 'jre' for Java 8 and 'jre-server' for 17/21
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch64.tar.xz $JRE_FOLDER_NAME
