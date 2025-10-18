#!/bin/bash
set -e

bash get_source.sh $TARGET_VERSION
cd openjdk

echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard
if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_aarch32.diff || true
elif [ "$TARGET_VERSION" -ge 17 ]; then
    find ../patches/Jre_${TARGET_VERSION} -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
fi

echo "Setting up NDK toolchain for aarch32..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TOOLCHAIN_PATH/bin/armv7a-linux-androideabi26-clang"
export CXX="$TOOLCHAIN_PATH/bin/armv7a-linux-androideabi26-clang++"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"

mkdir -p ../dummy_libs
ar cru ../dummy_libs/libpthread.a
ar cru ../dummy_libs/librt.a
ar cru ../dummy_libs/libthread_db.a

export CFLAGS="-fPIC -Wno-error -mfloat-abi=softfp -mfpu=vfp -O3 -D__ANDROID__"
export LDFLAGS="-L`pwd`/../dummy_libs -Wl,--undefined-version"

echo "Configuring build for Java $TARGET_VERSION on aarch32..."

# --- THE DEFINITIVE FIX: REMOVE ALL INCORRECT FLAGS, USE CONDITIONAL FLAGS ---
CONFIGURE_FLAGS=(
  --openjdk-target=arm-linux-androideabi
  --with-jvm-variants=server
  --with-boot-jdk=$JAVA_HOME
  --with-toolchain-type=clang
  --with-sysroot=$SYSROOT_PATH
  --with-extra-cflags="$CFLAGS"
  --with-extra-cxxflags="$CFLAGS"
  --with-extra-ldflags="$LDFLAGS"
  --with-debug-level=release
  --disable-precompiled-headers
)

# Add version-specific flags
if [ "$TARGET_VERSION" -ge 17 ]; then
  CONFIGURE_FLAGS+=(--disable-warnings-as-errors)
fi
# --- END OF FIX ---

bash ./configure "${CONFIGURE_FLAGS[@]}"

make images || (echo "Build failed once, retrying..." && make images)

echo "Build complete. Now repacking JRE..."
cd build/linux-arm-release/images
FULL_JRE_DIR=$(find . -type d -name "jre*" | head -n 1)
REPACKED_JRE_DIR="jre-server-minimal"

bash ../../../../repack_server_jre.sh "$TARGET_VERSION" "$FULL_JRE_DIR" "$REPACKED_JRE_DIR"

tar -cJf ../../../../jre${TARGET_VERSION}-aarch32.tar.xz "$REPACKED_JRE_DIR"
