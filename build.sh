#!/bin/bash
set -e

# This is the final, unified build script with specific fixes for each Java version.

LOGFILE=build.log
echo "Starting build for Java $TARGET_VERSION on $TARGET_ARCH"
echo "Logs will be saved to $LOGFILE"
echo

# Your excellent spinner and error-reporting function
run_with_spinner() {
  "$@" &> "$LOGFILE" &
  PID=$!
  while kill -0 $PID 2>/dev/null; do
    echo -n "."
    sleep 2
  done
  wait $PID
  STATUS=$?
  echo
  if [ $STATUS -ne 0 ]; then
    echo "Command failed: $*"
    echo "Last 200 lines of $LOGFILE:"
    tail -n 200 "$LOGFILE"
    exit $STATUS
  fi
}

# ====================================================================================
#  1. GLOBAL SETUP
# ====================================================================================

if [ "$TARGET_ARCH" == "aarch32" ]; then
  echo "Setting up for aarch32 (32-bit ARM)..."
  TARGET_OPENJDK="arm-linux-androideabi"
  COMPILER_PREFIX="armv7a-linux-androideabi26"
  EXTRA_CFLAGS="-mfloat-abi=softfp -mfpu=vfp"
  EXTRA_LDFLAGS=""
elif [ "$TARGET_ARCH" == "aarch64" ]; then
  echo "Setting up for aarch64 (64-bit ARM)..."
  TARGET_OPENJDK="aarch64-linux-androideabi"
  COMPILER_PREFIX="aarch64-linux-android26"
  EXTRA_CFLAGS=""
  EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
else
  echo "Unsupported architecture: $TARGET_ARCH"
  exit 1
fi

echo "Setting up NDK toolchain and library links..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"
ANDROID_INCLUDE="$SYSROOT_PATH/usr/include"

export CC="$TOOLCHAIN_PATH/bin/${COMPILER_PREFIX}-clang"
export CXX="$TOOLCHAIN_PATH/bin/${COMPILER_PREFIX}-clang++"
export AR="$TOOLCHAIN_PATH/bin/llvm-ar"
export NM="$TOOLCHAIN_PATH/bin/llvm-nm"
export STRIP="$TOOLCHAIN_PATH/bin/llvm-strip"
export RANLIB="$TOOLCHAIN_PATH/bin/llvm-ranlib"
export OBJCOPY="$TOOLCHAIN_PATH/bin/llvm-objcopy"

ln -s -f /usr/include/X11 $ANDROID_INCLUDE/
ln -s -f /usr/include/alsa $ANDROID_INCLUDE/
ln -s -f /usr/include/cups $ANDROID_INCLUDE/
ln -s -f /usr/include/fontconfig $ANDROID_INCLUDE/
ln -s -f /usr/include/freetype2 $ANDROID_INCLUDE/

mkdir -p dummy_libs
ar cru dummy_libs/libpthread.a
ar cru dummy_libs/librt.a
ar cru dummy_libs/libthread_db.a

# ====================================================================================
#  2. GET SOURCE, PATCH, AND CONFIGURE
# ====================================================================================

bash get_source.sh $TARGET_VERSION
cd openjdk
git reset --hard

# --- Base CFLAGS/LDFLAGS for all versions ---
export CFLAGS_BASE="-fPIC -O3 -D__ANDROID__ -DHEADLESS=1 ${EXTRA_CFLAGS}"
export LDFLAGS_BASE="-L`pwd`/../dummy_libs -Wl,--undefined-version ${EXTRA_LDFLAGS}"

# ------------------------- JAVA 8 -------------------------
if [ "$TARGET_VERSION" == "8" ]; then
  echo "--- Applying Java 8 Patches ---"
  git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
  if [ "$TARGET_ARCH" == "aarch32" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_aarch32.diff || true
  else
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff || true
  fi

  echo "--- Configuring Java 8 ---"
  # Java 8 needs explicit flags to find everything
  run_with_spinner bash ./configure \
    --openjdk-target=$TARGET_OPENJDK \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang \
    --with-sysroot=$SYSROOT_PATH \
    --with-extra-cflags="$CFLAGS_BASE" \
    --with-extra-cxxflags="$CFLAGS_BASE" \
    --with-extra-ldflags="$LDFLAGS_BASE" \
    --with-debug-level=release \
    --x-includes=/usr/include/X11 \
    --x-libraries=/usr/lib/`uname -m`-linux-gnu \
    --with-cups-include=/usr/include \
    --with-fontconfig-include=/usr/include \
    --with-freetype-include=/usr/include/freetype2 \
    --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu \
    --with-alsa=/usr/include/alsa

# ------------------------- JAVA 17 -------------------------
elif [ "$TARGET_VERSION" == "17" ]; then
  echo "--- Applying Java 17 Patches ---"
  find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'

  echo "--- Configuring Java 17 ---"
  # DEFINITIVE FIX for dlvsym redefinition
  export CFLAGS_V17="${CFLAGS_BASE} -D_LIBCPP_HAS_NO_DLFCN_H"
  run_with_spinner bash ./configure \
    --openjdk-target=$TARGET_OPENJDK \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang \
    --with-sysroot=$SYSROOT_PATH \
    --with-extra-cflags="$CFLAGS_V17" \
    --with-extra-cxxflags="$CFLAGS_V17" \
    --with-extra-ldflags="$LDFLAGS_BASE" \
    --with-debug-level=release \
    --disable-warnings-as-errors \
    --x-includes=/usr/include/X11 \
    --x-libraries=/usr/lib/`uname -m`-linux-gnu \
    --with-cups-include=/usr/include \
    --with-fontconfig-include=/usr/include \
    --with-freetype-include=/usr/include/freetype2 \
    --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu

# ------------------------- JAVA 21 -------------------------
elif [ "$TARGET_VERSION" == "21" ]; then
  echo "--- Applying Java 21 Patches ---"
  find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'

  echo "--- Configuring Java 21 ---"
  run_with_spinner bash ./configure \
    --openjdk-target=$TARGET_OPENJDK \
    --with-jvm-variants=server \
    --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang \
    --with-sysroot=$SYSROOT_PATH \
    --with-extra-cflags="$CFLAGS_BASE" \
    --with-extra-cxxflags="$CFLAGS_BASE" \
    --with-extra-ldflags="$LDFLAGS_BASE" \
    --with-debug-level=release \
    --with-native-debug-symbols=none \
    --disable-warnings-as-errors \
    --x-includes=/usr/include/X11 \
    --x-libraries=/usr/lib/`uname -m`-linux-gnu \
    --with-cups-include=/usr/include \
    --with-fontconfig-include=/usr/include \
    --with-freetype-include=/usr/include/freetype2 \
    --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu
fi

# ====================================================================================
#  3. COMPILE AND REPACK
# ====================================================================================

echo "--- Compiling ---"
run_with_spinner make images

echo "--- Repacking JRE ---"
BUILD_DIR_ARCH=$(echo "$TARGET_OPENJDK" | sed 's/-androideabi//')
cd build/linux-${BUILD_DIR_ARCH}-release/images
FULL_JRE_DIR=$(find . -type d -name "jre*" | head -n 1)
REPACKED_JRE_DIR="jre-server-minimal"

bash ../../../../repack_server_jre.sh "$TARGET_VERSION" "$FULL_JRE_DIR" "$REPACKED_JRE_DIR"

tar -cJf ../../../../jre${TARGET_VERSION}-${TARGET_ARCH}.tar.xz "$REPACKED_JRE_DIR"

echo "Build and repack complete!"
