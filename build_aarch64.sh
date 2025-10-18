#!/bin/bash
set -e

# This script builds for 64-bit ARM (arm64-v8a)

bash get_source.sh $TARGET_VERSION
cd openjdk

# --- THE DEFINITIVE FIX: EXPLICIT PATCHING FOR ALL VERSIONS ---
echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard
if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff || true
elif [ "$TARGET_VERSION" == "17" ]; then
    find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
elif [ "$TARGET_VERSION" == "21" ]; then
    find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
fi
# --- END OF FIX ---

echo "Setting up NDK toolchain for aarch64..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TOOLCHAIN_PATH/bin/aarch64-linux-android26-clang"
export CXX="$TOOLCHAIN_PATH/bin/aarch64-linux-android26-clang++"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"

mkdir -p ../dummy_libs
ar cru ../dummy_libs/libpthread.a
ar cru ../dummy_libs/librt.a
ar cru ../dummy_libs/libthread_db.a

export CFLAGS="-fPIC -Wno-error -O3 -D__ANDROID__ -DHEADLESS=1"
export LDFLAGS="-L`pwd`/../dummy_libs -Wl,--undefined-version -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"

echo "Configuring build for Java $TARGET_VERSION on aarch64..."

CONFIGURE_FLAGS=(
  --openjdk-target=aarch64-linux-androideabi
  --with-jvm-variants=server
  --with-boot-jdk=$JAVA_HOME
  --with-toolchain-type=clang
  --with-sysroot=$SYSROOT_PATH
  --with-extra-cflags="$CFLAGS"
  --with-extra-cxxflags="$CFLAGS"
  --with-extra-ldflags="$LDFLAGS"
  --with-debug-level=release
  --disable-precompiled-headers
  --without-cups
)

# --- THE DEFINITIVE FIX: EXPLICIT CONFIGURE FLAGS FOR ALL VERSIONS ---
if [ "$TARGET_VERSION" == "8" ]; then
  CONFIGURE_FLAGS+=(
    --disable-headful
    --disable-deploy
    --disable-javaws
  )
elif [ "$TARGET_VERSION" == "17" ]; then
  CONFIGURE_FLAGS+=(
    --enable-headless-only=yes
    --disable-warnings-as-errors
    --with-jvm-features=-dtrace,-zero,-vm-structs,-epsilongc
  )
elif [ "$TARGET_VERSION" == "21" ]; then
  CONFIGURE_FLAGS+=(
    --enable-headless-only=yes
    --disable-warnings-as-errors
    --disable-alsa
    --with-jvm-features=-dtrace,-zero,-vm-structs,-epsilongc
  )
fi
# --- END OF FIX ---

bash ./configure "${CONFIGURE_FLAGS[@]}"

make images || (echo "Build failed once, retrying..." && make images)

echo "Build complete. Now repacking JRE..."
cd build/linux-aarch64-release/images
FULL_JRE_DIR=$(find . -type d -name "jre*" | head -n 1)
REPACKED_JRE_DIR="jre-server-minimal"

bash ../../../../repack_server_jre.sh "$TARGET_VERSION" "$FULL_JRE_DIR" "$REPACKED_JRE_DIR"

tar -cJf ../../../../jre${TARGET_VERSION}-aarch64.tar.xz "$REPACKED_JRE_DIR"
