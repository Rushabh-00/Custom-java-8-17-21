#!/bin/bash
set -e

# This script builds for 32-bit ARM (armeabi-v7a)

# Get Source Code
bash get_source.sh $TARGET_VERSION
cd openjdk

# Configure the build
bash ./configure \
    --openjdk-target=arm-linux-androideabi \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=gcc \
    --with-extra-cflags="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp" \
    --with-extra-cxxflags="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp" \
    --with-extra-ldflags="-Wl,-rpath-link=$JAVA_HOME/jre/lib/arm"

# Run the build
make images

# After building, find the created JRE image and package it
cd build/linux-arm-release/images
# The folder is named 'jre' for Java 8 and 'jre-server' for 17/21
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch32.tar.xz $JRE_FOLDER_NAME
