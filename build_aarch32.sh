#!/bin/bash
set -e

# This script builds for 32-bit ARM (armeabi-v7a)

bash get_source.sh $TARGET_VERSION
cd openjdk

echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard
# Use '|| true' to ignore expected, non-fatal patch errors
if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_aarch32.diff || true
elif [ "$TARGET_VERSION" == "17" ]; then
    find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
elif [ "$TARGET_VERSION" == "21" ]; then
    find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
fi

echo "Setting up NDK toolchain for aarch32..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TOOLCHAIN_PATH/bin/armv7a-linux-androideabi26-clang"
export CXX="$TOOLCHAIN_PATH/bin/armv7a-linux-androideabi26-clang++"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"

echo "Configuring build for Java $TARGET_VERSION on aarch32..."

# Base configure flags for a server build
CONFIGURE_FLAGS=(
  --openjdk-target=arm-linux-androideabi
  --with-jvm-variants=server
  --with-boot-jdk=$JAVA_HOME
  --with-toolchain-type=clang
  --with-sysroot=$SYSROOT_PATH
  --with-extra-cflags="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp"
  --with-extra-cxxflags="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp"
  --with-extra-ldflags="-Wl,-rpath-link=$JAVA_HOME/jre/lib/arm"
  --with-debug-level=release
  --disable-precompiled-headers
  --with-cups-include=$CUPS_DIR
)

# --- THE DEFINITIVE FIX: EXPLICIT HEADLESS FLAGS FOR EACH VERSION ---
if [ "$TARGET_VERSION" == "8" ]; then
  CONFIGURE_FLAGS+=(
  --disable-headful)
elif [ "$TARGET_VERSION" == "17" ]; then
  CONFIGURE_FLAGS+=(
  --enable-headless-only=yes
  --disable-warnings-as-errors)
elif [ "$TARGET_VERSION" == "21" ]; then
  CONFIGURE_FLAGS+=(
  --enable-headless-only=yes
  --disable-warnings-as-errors)
fi
# --- END OF FIX ---

# Run configure with all flags
bash ./configure "${CONFIGURE_FLAGS[@]}"

make images

cd build/linux-arm-release/images
JRE_FOLDER_NAME=$(find . -type d -name "jre*" | head -n 1)
tar -cJf ../../../../jre${TARGET_VERSION}-aarch32.tar.xz $JRE_FOLDER_NAME
