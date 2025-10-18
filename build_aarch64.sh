#!/bin/bash
set -e

# This script builds for 64-bit ARM (arm64-v8a)

# Get Source Code
bash get_source.sh $TARGET_VERSION
cd openjdk

# --- THE DEFINITIVE FIX: USE THE CORRECT PATCHING LOGIC ---
echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard # Clean the repository before applying

if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff
    # We are building for aarch64, so apply the main (non-aarch32) patch
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff

elif [ "$TARGET_VERSION" == "17" ]; then
    # Find and apply all patches in the Jre_17 directory
    find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {}'

elif [ "$TARGET_VERSION" == "21" ]; then
    # Find and apply all patches in the Jre_21 directory
    find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {}'
fi
# --- END OF FIX ---

# Configure the build
echo "Configuring build for Java $TARGET_VERSION on aarch64..."
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
