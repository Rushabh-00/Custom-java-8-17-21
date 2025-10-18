#!/bin/bash
set -e

# This script builds for 64-bit ARM (arm64-v8a)

bash get_source.sh $TARGET_VERSION
cd openjdk

echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard

if [ "$TARGET_VERSION" == "8" ]; then
    # Apply Java 8 specific patches, ignoring expected "failures"
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff || true
elif [ "$TARGET_VERSION" == "17" ]; then
    find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
elif [ "$TARGET_VERSION" == "21" ]; then
    find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
fi

echo "Setting up NDK toolchain for aarch64..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TOOLCHAIN_PATH/bin/aarch64-linux-android26-clang"
export CXX="$TOOLCHAIN_PATH/bin/aarch64-linux-android26-clang++"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"

echo "Configuring build for Java $TARGET_VERSION on aarch64..."
bash ./configure \
    --openjdk-target=aarch64-linux-androideabi \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang \
    --with-sysroot=$SYSROOT_PATH \
    --with-extra-cflags="-fPIC -Wno-error" \
    --with-extra-cxxflags="-fPIC -Wno-error" \
    --with-extra-ldflags="-Wl,-rpath-link=$JAVA_HOME/jre/lib/aarch64" \
    --disable-x11
    --disable-alsa

make images

cd build/linux-aarch64-release/images
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch64.tar.xz $JRE_FOLDER_NAME
