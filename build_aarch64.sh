#!/bin/bash
set -e

# This script builds for 64-bit ARM (arm64-v8a)

# Get Source Code
bash get_source.sh $TARGET_VERSION
cd openjdk

# Apply our local patches
echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard
if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff
elif [ "$TARGET_VERSION" == "17" ]; then
    find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {}'
elif [ "$TARGET_VERSION" == "21" ]; then
    find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {}'
fi

# --- THE DEFINITIVE FIX: SET UP THE NDK TOOLCHAIN CORRECTLY ---
echo "Setting up NDK toolchain for aarch64..."
# Define the path to the NDK toolchain binaries
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"

# Export the C and C++ compilers for the target architecture (API level 26)
export CC="$TOOLCHAIN_PATH/bin/aarch64-linux-android26-clang"
export CXX="$TOOLCHAIN_PATH/bin/aarch64-linux-android26-clang++"

# Define the path to the system root (headers and libraries)
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"
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
    --with-sysroot=$SYSROOT_PATH

# Run the build
make images

# After building, find the created JRE image and package it
cd build/linux-aarch64-release/images
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch64.tar.xz $JRE_FOLDER_NAME
