#!/bin/bash
set -e

# This is the single, unified build script that handles all Java versions and architectures.

# 1. ========== SETUP ENVIRONMENT BASED ON ARCHITECTURE ==========
if [ "$TARGET_ARCH" == "aarch32" ]; then
  echo "Setting up for aarch32 (32-bit ARM)..."
  TARGET_OPENJDK="arm-linux-androideabi"
  COMPILER_PREFIX="armv7a-linux-androideabi26"
  EXTRA_CFLAGS="-mfloat-abi=softfp -mfpu=vfp"
  EXTRA_LDFLAGS=""
  # Add the critical -DARM flag for Java 17/21 HotSpot compilation
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

# 2. ========== SETUP NDK AND SYSTEM LIBRARIES ==========
echo "Setting up NDK toolchain and library links..."
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT_PATH="$TOOLCHAIN_PATH/sysroot"
ANDROID_INCLUDE="$SYSROOT_PATH/usr/include"

# Set compilers and tools from the NDK, as seen in MojoLauncher scripts
export CC="$TOOLCHAIN_PATH/bin/${COMPILER_PREFIX}-clang"
export CXX="$TOOLCHAIN_PATH/bin/${COMPILER_PREFIX}-clang++"
export AR="$TOOLCHAIN_PATH/bin/llvm-ar"
export NM="$TOOLCHAIN_PATH/bin/llvm-nm"
export STRIP="$TOOLCHAIN_PATH/bin/llvm-strip"
export RANLIB="$TOOLCHAIN_PATH/bin/llvm-ranlib"
export OBJCOPY="$TOOLCHAIN_PATH/bin/llvm-objcopy"

# Create symbolic links to host libraries, a critical step
ln -s -f /usr/include/X11 $ANDROID_INCLUDE/
ln -s -f /usr/include/alsa $ANDROID_INCLUDE/
ln -s -f /usr/include/cups $ANDROID_INCLUDE/
ln -s -f /usr/include/fontconfig $ANDROID_INCLUDE/
ln -s -f /usr/include/freetype2 $ANDROID_INCLUDE/

# Create dummy libraries to satisfy the linker
mkdir -p dummy_libs
ar cru dummy_libs/libpthread.a
ar cru dummy_libs/librt.a
ar cru dummy_libs/libthread_db.a

# 3. ========== GET AND PATCH SOURCE CODE ==========
bash get_source.sh $TARGET_VERSION
cd openjdk

echo "Applying patches for Java $TARGET_VERSION..."
git reset --hard
if [ "$TARGET_VERSION" == "8" ]; then
    git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android.diff || true
    if [ "$TARGET_ARCH" == "aarch32" ]; then
      git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_aarch32.diff || true
    else
      git apply --reject --whitespace=fix ../patches/Jre_8/jdk8u_android_main.diff || true
    fi
elif [ "$TARGET_VERSION" -ge 17 ]; then
    find ../patches/Jre_${TARGET_VERSION} -name "*.diff" -print0 | xargs -0 -I {} sh -c 'echo "Applying {}" && git apply --reject --whitespace=fix {} || true'
fi

# 4. ========== CONFIGURE THE BUILD ==========
echo "Configuring build for Java $TARGET_VERSION on $TARGET_ARCH..."

# Universal flags
export CFLAGS_BASE="-fPIC -O3 -D__ANDROID__ -DHEADLESS=1 ${EXTRA_CFLAGS}"
export LDFLAGS_BASE="-L`pwd`/../dummy_libs -Wl,--undefined-version ${EXTRA_LDFLAGS}"

# Configure flags common to all versions
CONFIGURE_FLAGS=(
  --openjdk-target=$TARGET_OPENJDK
  --with-jvm-variants=server
  --with-boot-jdk=$JAVA_HOME
  --with-toolchain-type=clang
  --with-sysroot=$SYSROOT_PATH
  --with-extra-cflags="$CFLAGS_BASE"
  --with-extra-cxxflags="$CFLAGS_BASE" # Use same flags for C and C++
  --with-extra-ldflags="$LDFLAGS_BASE"
  --with-debug-level=release
  --with-native-debug-symbols=none
  --disable-precompiled-headers
  --x-includes=/usr/include/X11
  --x-libraries=/usr/lib/`uname -m`-linux-gnu
  --with-cups-include=/usr/include
  --with-fontconfig-include=/usr/include
  --with-freetype-include=/usr/include/freetype2
  --with-freetype-lib=/usr/lib/`uname -m`-linux-gnu
)

# Version-specific flags
if [ "$TARGET_VERSION" == "8" ]; then
  CONFIGURE_FLAGS+=(--with-alsa=/usr/include/alsa)
else
  # Modern Java versions can have warnings treated as errors disabled
  CONFIGURE_FLAGS+=(--disable-warnings-as-errors)
fi

bash ./configure "${CONFIGURE_FLAGS[@]}"

# 5. ========== COMPILE AND REPACK ==========
make images || (echo "Build failed once, retrying..." && make images)

echo "Build complete. Now repacking JRE..."
BUILD_DIR_ARCH=$(echo "$TARGET_OPENJDK" | sed 's/-androideabi//')
cd build/linux-${BUILD_DIR_ARCH}-release/images
FULL_JRE_DIR=$(find . -type d -name "jre*" | head -n 1)
REPACKED_JRE_DIR="jre-server-minimal"

bash ../../../../repack_server_jre.sh "$TARGET_VERSION" "$FULL_JRE_DIR" "$REPACKED_JRE_DIR"

tar -cJf ../../../../jre${TARGET_VERSION}-${TARGET_ARCH}.tar.xz "$REPACKED_JRE_DIR"
