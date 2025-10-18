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
    --openjdk-target=arm-linux-androideabi \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=gcc \
    --with-extra-cflags="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp" \
    --with-extra-cxxflags="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp" \
    --with-extra-ldflags="-Wl,-rpath-link=$JAVA_HOME/jre/lib/arm" \
    --with-ndk=$NDK_PATH

# Run the build
make images

# After building, find the created JRE image and package it
cd build/linux-arm-release/images
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch32.tar.xz $JRE_FOLDER_NAME
