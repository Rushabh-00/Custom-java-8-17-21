#!/bin/bash
set -e

LOGFILE=build.log
echo "Starting build for Java $TARGET_VERSION on $TARGET_ARCH" > "$LOGFILE"
echo "Logs will be saved to $LOGFILE"
echo

run_with_spinner() {
  # This function runs a command in the background, redirects its output to the logfile,
  # and shows a spinner. If the command fails, it prints the end of the logfile.
  "$@" >> "$LOGFILE" 2>&1 &
  PID=$!
  while kill -0 $PID 2>/dev/null; do
    echo -n "."
    sleep 5
  done
  wait $PID
  STATUS=$?
  echo
  if [ $STATUS -ne 0 ]; then
    echo "Command FAILED with status $STATUS: $*"
    echo "Showing last 200 lines of $LOGFILE:"
    echo "======================================================================="
    tail -n 200 "$LOGFILE"
    echo "======================================================================="
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
  if [ "$TARGET_VERSION" -ge 17 ]; then
    EXTRA_CFLAGS+=" -DARM"
  fi
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

echo "Setting up NDK toolchain and environment..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"
export CC="$TOOLCHAIN_PATH/bin/${COMPILER_PREFIX}-clang"
export CXX="$TOOLCHAIN_PATH/bin/${COMPILER_PREFIX}-clang++"
export AR="$TOOLCHAIN_PATH/bin/llvm-ar"
export NM="$TOOLCHAIN_PATH/bin/llvm-nm"
export STRIP="$TOOLCHAIN_PATH/bin/llvm-strip"
export RANLIB="$TOOLCHAIN_PATH/bin/llvm-ranlib"

mkdir -p dummy_libs
ar cru dummy_libs/libpthread.a
ar cru dummy_libs/librt.a
ar cru dummy_libs/libthread_db.a

export CFLAGS_BASE="-fPIC -O3 -D__ANDROID__ -DHEADLESS=1 ${EXTRA_CFLAGS}"
export LDFLAGS_BASE="-L`pwd`/dummy_libs -Wl,--undefined-version ${EXTRA_LDFLAGS}"

# ====================================================================================
#  2. GET SOURCE, PATCH, AND CONFIGURE
# ====================================================================================

run_with_spinner bash get_source.sh $TARGET_VERSION
cd openjdk
git reset --hard

# --- Separate Patch Logic ---
if [ "$TARGET_VERSION" == "8" ]; then
  echo "--- Applying Java 8 Patches ---"
  git apply --reject --whitespace=fix ../patches/Jre_8/*.diff || true
elif [ "$TARGET_VERSION" == "17" ]; then
  echo "--- Applying Java 17 Patches ---"
  find ../patches/Jre_17 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
elif [ "$TARGET_VERSION" == "21" ]; then
  echo "--- Applying Java 21 Patches ---"
  find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
fi

# --- Separate Configure Logic ---
echo "--- Configuring Java $TARGET_VERSION ---"

if [ "$TARGET_VERSION" == "8" ]; then
  # For Java 8, we do not disable warnings as errors.
  CONFIGURE_COMMAND=(
    bash ./configure
    --openjdk-target=$TARGET_OPENJDK
    --with-jvm-variants=server
    --with-boot-jdk=$JAVA_HOME
    --with-toolchain-type=clang
    --with-sysroot=$SYSROOT_PATH
    --with-extra-cflags="$CFLAGS_BASE"
    --with-extra-cxxflags="$CFLAGS_BASE"
    --with-extra-ldflags="$LDFLAGS_BASE"
    --with-debug-level=release
    --disable-precompiled-headers
  )
elif [ "$TARGET_VERSION" == "17" ]; then
  # Add the dlvsym fix CFLAG for Java 17
  CFLAGS_FOR_17="$CFLAGS_BASE -D_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER"
  CONFIGURE_COMMAND=(
    bash ./configure
    --openjdk-target=$TARGET_OPENJDK
    --with-jvm-variants=server
    --with-boot-jdk=$JAVA_HOME
    --with-toolchain-type=clang
    --with-sysroot=$SYSROOT_PATH
    --with-extra-cflags="$CFLAGS_FOR_17"
    --with-extra-cxxflags="$CFLAGS_FOR_17"
    --with-extra-ldflags="$LDFLAGS_BASE"
    --with-debug-level=release
    --disable-precompiled-headers
    --disable-warnings-as-errors
  )
elif [ "$TARGET_VERSION" == "21" ]; then
  # Add the gdwarf-4 fix CFLAG for Java 21
  CFLAGS_FOR_21="$CFLAGS_BASE -gdwarf-4"
  CONFIGURE_COMMAND=(
    bash ./configure
    --openjdk-target=$TARGET_OPENJDK
    --with-jvm-variants=server
    --with-boot-jdk=$JAVA_HOME
    --with-toolchain-type=clang
    --with-sysroot=$SYSROOT_PATH
    --with-extra-cflags="$CFLAGS_FOR_21"
    --with-extra-cxxflags="$CFLAGS_FOR_21"
    --with-extra-ldflags="$LDFLAGS_BASE"
    --with-debug-level=release
    --disable-precompiled-headers
    --disable-warnings-as-errors
  )
fi

run_with_spinner "${CONFIGURE_COMMAND[@]}"

# ====================================================================================
#  3. COMPILE AND REPACK
# ====================================================================================

echo "--- Compiling Java $TARGET_VERSION ---"
# --- YOUR SUPERIOR RETRY AND LOGGING LOGIC, RESTORED ---
make images >> "$LOGFILE" 2>&1 || {
  echo
  echo "Build FAILED on first attempt. Retrying once..."
  # Run the make command again
  make images >> "$LOGFILE" 2>&1 || {
    echo
    echo "Build FAILED after second attempt."
    echo "Showing last 200 lines of $LOGFILE:"
    echo "======================================================================="
    tail -n 200 "$LOGFILE"
    echo "======================================================================="
    exit 1
  }
}
# --- END OF RESTORED LOGIC ---

echo "--- Repacking JRE for Java $TARGET_VERSION ---"
BUILD_DIR_ARCH=$(echo "$TARGET_OPENJDK" | sed 's/-androideabi//')
cd build/linux-${BUILD_DIR_ARCH}-release/images
FULL_JRE_DIR=$(find . -type d -name "jre*" | head -n 1)
REPACKED_JRE_DIR="jre-server-minimal"

run_with_spinner bash ../../../../repack_server_jre.sh "$TARGET_VERSION" "$FULL_JRE_DIR" "$REPACKED_JRE_DIR"

run_with_spinner tar -cJf ../../../../jre${TARGET_VERSION}-${TARGET_ARCH}.tar.xz "$REPACKED_JRE_DIR"

echo "Build and repack complete for Java $TARGET_VERSION on $TARGET_ARCH!"
