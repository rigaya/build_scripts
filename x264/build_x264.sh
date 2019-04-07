#!/bin/sh
# msys2用x264ビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=`pwd`/build_x264
BUILD_CCFLAGS="-msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include" 
BUILD_LDFLAGS="-static -static-libgcc -Wl,--gc-sections -Wl,--strip-all -L${INSTALL_DIR}/lib"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
Y4M_PATH="`pwd`/husky.y4m"
Y4M_XZ_PATH="`pwd`/husky.tar.xz"
X264_MAKEFILE_PATCH="`pwd`/patch/x264_makefile.diff"

#download
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src
git config --global core.autocrlf false

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
    BUILD_CCFLAGS="-m32 ${BUILD_CCFLAGS}"
else
    TARGET_ARCH="x64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ -d "x264" ]; then
    cd x264
    git pull
    cd ..
else
	git clone git@code.videolan.org:videolan/x264.git x264
fi

if [ -d "l-smash" ]; then
    cd l-smash
    git pull
    cd ..
else
	git clone https://github.com/l-smash/l-smash.git l-smash
fi

mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "x264" ]; then
    rm -rf x264
fi
cp -r ../src/x264 x264

if [ -d "l-smash" ]; then
    rm -rf l-smash
fi
cp -r ../src/l-smash l-smash

if [ ! -e $Y4M_PATH ]; then
	tar xf $Y4M_XZ_PATH -C `dirname $Y4M_PATH`
fi

#build L-SMASH
cd $BUILD_DIR/$TARGET_ARCH/L-SMASH
./configure \
--prefix=$INSTALL_DIR \
--extra-cflags="${BUILD_CCFLAGS}" \
--extra-ldflags="${BUILD_LDFLAGS}"
make clean && make -j$MAKE_PROCESS install-lib


#build x264
echo "Start build x264(${TARGET_ARCH})"
cd $BUILD_DIR/$TARGET_ARCH/x264
X264_REV=`git rev-list HEAD | wc -l`
patch < $X264_MAKEFILE_PATCH
export X264_REV=$X264_REV

PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
 --prefix=$INSTALL_DIR \
 --host=$MINGW_CHOST \
 --enable-strip \
 --disable-ffms \
 --disable-gpac \
 --disable-lavf \
 --bit-depth=all \
 --extra-cflags="-O3 ${BUILD_CCFLAGS}" \
 --extra-ldflags="${BUILD_LDFLAGS}"
make fprofiled VIDS="${Y4M_PATH}" -j$MAKE_PROCESS
cp -f x264.exe x264_${X264_REV}_$TARGET_ARCH.exe
