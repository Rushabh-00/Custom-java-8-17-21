#!/bin/bash
set -e

# This script builds for 32-bit ARM (armeabi-v7a)

# Get Source Code
bash get_source.sh $TARGET_VERSION
cd openjdk

# --- THE DEFINITIVE FIX: USE THE CORRECT PATCHING LOGIC ---
echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard # Clean the repository before applying

if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff
    # We are building for aarch32, so apply the aarch32 specific patch
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_aarch32.diff

elif [ "$TARGET_VERSION" == "17" ]; then
    # Find and apply all patches in the Jre_17 directory
    find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {}'

elif [ "$TARGET_VERSION" == "21" ]; then
    # Find and apply all patches in the Jre_21 directory
    find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {}'
fi
# --- END OF FIX ---

# Configure the build
echo "Configuring build for Java $TARGET_VERSION on aarch32..."
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
