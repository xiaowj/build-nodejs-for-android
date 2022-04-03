#/bin/bash
set -xe

MEDIR=$(cd `dirname $0`; pwd)
ME=node-v16.13.1

cd $MEDIR

SELF=$(cd `dirname $0`; pwd)

export NDK="/github/build-nodejs/android-ndk-r23b"
export ENVSRCTARBALL=""
export HOST_GCC_DIR="/usr"
export ENVDISTBIN="dist"
export ENVHOST=linux-x86_64
export ENVTARGET=aarch64-linux-android
export ENVANDROIDVER=23
export CROSS_COMPILE="--build=x86_64-linux --host=arm-eabi --target=arm-eabi"

if [ -f $SELF/local/env.sh ]; then
   source $SELF/local/env.sh
fi

if [ "$NDK" == "" ]; then
   echo 'check:    ENVHOST, ENVTARGET, ENVANDROIDVER'
   echo
   echo 'run cmd:  mkdir local; touch local/env.sh'
   echo 'fill:     NDK, ENVSRCTARBALL'
   echo 'optional: HOST_GCC_DIR'
   exit 0
fi

export COMPILERDIR="$NDK/toolchains/llvm/prebuilt/$ENVHOST/bin"
export CC="$COMPILERDIR/${ENVTARGET}${ENVANDROIDVER}-clang"
export CXX="$COMPILERDIR/${ENVTARGET}${ENVANDROIDVER}-clang++"
export LD="$COMPILERDIR/$ENVTARGET-ld"
export AS="$COMPILERDIR/$ENVTARGET-as"
export AR="$COMPILERDIR/llvm-ar"
export STRIP="$COMPILERDIR/llvm-strip"
export OBJCOPY="$COMPILERDIR/llvm-objcopy"
export OBJDUMP="$COMPILERDIR/llvm-objdump"
export RANLIB="$COMPILERDIR/llvm-ranlib"
export NM="$COMPILERDIR/llvm-nm"
export STRINGS="$COMPILERDIR/llvm-strings"
export READELF="$COMPILERDIR/llvm-readelf"

export ANDROID="$COMPILERDIR/../sysroot"

function fetch_source() {
# $1: package file name, e.g. vim-7.4.0001.tar.gz
# $2: source url
  test -f "$ENVSRCTARBALL/$1" || curl -k -L -o "$ENVSRCTARBALL/$1" "$2"
  test -f "$ENVSRCTARBALL/$1" || exit 1
}

cd ..
rm -rf $ME
fetch_source $ME.tar.gz https://nodejs.org/dist/v16.13.1/node-v16.13.1.tar.gz
tar zxf $ENVSRCTARBALL/$ME.tar.gz
cd $ME

# by default, build for arm64
ARCH=arm64
DEST_CPU=arm64
HOST_OS="linux"
HOST_ARCH="x86_64"

if [ "$HOST_GCC_DIR" == "" ]; then
if [ ! -d $MEDIR/local/gcc-9.3.0 ]; then
   cat <<EOF
it will start to compile gcc-9.3.0;
if you have any (gcc >= 6.3), please stop the script and
   - set CC_host, CXX_host, AR_host, RANLIB_host
   - or set HOST_GCC_DIR to the specified GCC root directory
EOF
   sleep 10
   # build gcc-9.3.0
   bash host_gcc_9.3.sh
   HOST_GCC_DIR=$MEDIR/local/gcc-9.3.0/dist
fi
fi

echo host gcc: $HOST_GCC_DIR

export CC_host=$HOST_GCC_DIR/bin/gcc
export CXX_host=$HOST_GCC_DIR/bin/g++
export AR_host=$HOST_GCC_DIR/bin/gcc-ar
export RANLIB_host=$HOST_GCC_DIR/bin/gcc-ranlib
export LD_LIBRARY_PATH=$HOST_GCC_DIR/lib64:$LD_LIBRARY_PATH

GYP_DEFINES="target_arch=$ARCH"
GYP_DEFINES+=" v8_target_arch=$ARCH"
GYP_DEFINES+=" android_target_arch=$ARCH"
GYP_DEFINES+=" host_os=$HOST_OS OS=android"
export GYP_DEFINES

./configure \
    --prefix=$MEDIR/../dist/$ME \
    --dest-cpu=$DEST_CPU \
    --dest-os=android \
    --without-snapshot \
    --openssl-no-asm \
    --cross-compiling \
    --shared

grep "LD_LIBRARY_PATH=" . -r | grep -v Binary | cut -d ':' -f 1 | sort -u | xargs sed -i "s|LD_LIBRARY_PATH=|LD_LIBRARY_PATH=$HOST_GCC_DIR/dist/lib64:|g"

# make sure some functions are available in link stage
sed -i 's|/poll.o \\|/poll.o \\\n\t$(obj).target/$(TARGET)/deps/uv/src/unix/epoll.o \\|' out/deps/uv/libuv.target.mk

# disable TRAP_HANDLER
sed -i "s|// Setup for shared library export.|#undef V8_TRAP_HANDLER_VIA_SIMULATOR\n#undef V8_TRAP_HANDLER_SUPPORTED\n#define V8_TRAP_HANDLER_SUPPORTED false\n\n// Setup for shared library export.|" deps/v8/src/trap-handler/trap-handler.h

make -j4