#!/bin/bash
set -e

# This is the single, unified build script that handles all Java versions and architectures.
# It contains specific fixes for all known build errors.

LOGFILE=build.log
echo "Starting build for Java $TARGET_VERSION on $TARGET_ARCH. Logs will be saved to $LOGFILE"
echo

run_with_spinner() {
  # Hide stdout, redirect stderr to stdout, and tee to logfile
  { "$@" 2>&1; } > "$LOGFILE" &
  PID=$!
  while kill -0 $PID 2>/dev/null; do
    echo -n "."
    sleep 5
  done
  wait $PID
  STATUS=$?
  echo
  if [ $STATUS -ne 0 ]; then
    echo "ERROR: Command failed with status $STATUS: $*"
    echo "--- Last 200 lines of log ---"
    tail -n 200 "$LOGFILE"
    exit $STATUS
  fi
}

# ====================================================================================
#  1. GLOBAL SETUP (NDK, Compilers, System Libraries)
# ====================================================================================

if [ "$TARGET_ARCH" == "aarch32" ]; then
  TARGET_OPENJDK="arm-linux-androideabi"
  COMPILER_PREFIX="armv7a-linux-androideabi26"
  EXTRA_CFLAGS="-mfloat-abi=softfp -mfpu=vfp"
  EXTRA_LDFLAGS=""
  if [ "$TARGET_VERSION" -ge 17 ]; then
    EXTRA_CFLAGS+=" -DARM"
  fi
elif [ "$TARGET_ARCH" == "aarch64" ]; then
  TARGET_OPENJDK="aarch64-linux-androideabi"
  COMPILER_PREFIX="aarch64-linux-android26"
  EXTRA_CFLAGS=""
  EXTRA_LDFLAGS="-Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384"
else
  echo "Unsupported architecture: $TARGET_ARCH"; exit 1;
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
#  2. GET SOURCE, PATCH, AND CONFIGURE BASED ON VERSION
# ====================================================================================

run_with_spinner bash get_source.sh $TARGET_VERSION
cd openjdk
git reset --hard

# --- DEFINITIVE FIX: SEPARATE, CORRECT PATCHING AND CONFIGURATION FOR EACH VERSION ---

if [ "$TARGET_VERSION" == "8" ]; then
  # --------- JAVA 8 ---------
  echo "--- Applying Java 8 Patches ---"
  git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
  if [ "$TARGET_ARCH" == "aarch32" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_aarch32.diff || true
  else
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff || true
  fi
  
  export CFLAGS_VERSION="-fPIC -O3 -D__ANDROID__ -DHEADLESS=1 ${EXTRA_CFLAGS}"
  export LDFLAGS_VERSION="-L`pwd`/../dummy_libs -Wl,--undefined-version ${EXTRA_LDFLAGS}"
  
  echo "--- Configuring Java 8 ---"
  run_with_spinner bash ./configure \
    --openjdk-target=$TARGET_OPENJDK --with-jvm-variants=server --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang --with-sysroot=$SYSROOT_PATH --with-extra-cflags="$CFLAGS_VERSION" \
    --with-extra-cxxflags="$CFLAGS_VERSION" --with-extra-ldflags="$LDFLAGS_VERSION" \
    --with-debug-level=release --disable-precompiled-headers --x-includes=/usr/include/X11 \
    --x-libraries=/usr/lib/`uname -m`-linux-gnu --with-cups-include=/usr/include \
    --with-fontconfig-include=/usr/include --with-freetype-include=/usr/include/freetype2 \
    --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu --with-alsa=/usr/include/alsa

elif [ "$TARGET_VERSION" == "17" ]; then
  # --------- JAVA 17 ---------
  echo "--- Applying Java 17 Patches ---"
  # THE FIX: Exclude the patch causing the 'dlvsym' redefinition error.
  find ../patches/Jre_17 -name "*.diff" ! -name "16_fix_jni_util_md.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'

  export CFLAGS_VERSION="-fPIC -O3 -D__ANDROID__ -DHEADLESS=1 ${EXTRA_CFLAGS}"
  export LDFLAGS_VERSION="-L`pwd`/../dummy_libs -Wl,--undefined-version ${EXTRA_LDFLAGS}"

  echo "--- Configuring Java 17 ---"
  run_with_spinner bash ./configure \
    --openjdk-target=$TARGET_OPENJDK --with-jvm-variants=server --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang --with-sysroot=$SYSROOT_PATH --with-extra-cflags="$CFLAGS_VERSION" \
    --with-extra-cxxflags="$CFLAGS_VERSION" --with-extra-ldflags="$LDFLAGS_VERSION" \
    --with-debug-level=release --disable-precompiled-headers --disable-warnings-as-errors \
    --x-includes=/usr/include/X11 --x-libraries=/usr/lib/`uname -m`-linux-gnu \
    --with-cups-include=/usr/include --with-fontconfig-include=/usr/include \
    --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu

elif [ "$TARGET_VERSION" == "21" ]; then
  # --------- JAVA 21 ---------
  echo "--- Applying Java 21 Patches ---"
  find ../patches/Jre_21 -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'

  # THE FIX: Add '-gno-dwarf-5' to fix the '-gdwarf-' error with modern clang.
  export CFLAGS_VERSION="-fPIC -O3 -D__ANDROID__ -DHEADLESS=1 ${EXTRA_CFLAGS} -gno-dwarf-5"
  export LDFLAGS_VERSION="-L`pwd`/../dummy_libs -Wl,--undefined-version ${EXTRA_LDFLAGS}"

  echo "--- Configuring Java 21 ---"
  run_with_spinner bash ./configure \
    --openjdk-target=$TARGET_OPENJDK --with-jvm-variants=server --with-boot-jdk=$JAVA_HOME \
    --with-toolchain-type=clang --with-sysroot=$SYSROOT_PATH --with-extra-cflags="$CFLAGS_VERSION" \
    --with-extra-cxxflags="$CFLAGS_VERSION" --with-extra-ldflags="$LDFLAGS_VERSION" \
    --with-debug-level=release --disable-precompiled-headers --disable-warnings-as-errors \
    --x-includes=/usr/include/X11 --x-libraries=/usr/lib/`uname -m`-linux-gnu \
    --with-cups-include=/usr/include --with-fontconfig-include=/usr/include \
    --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu
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
