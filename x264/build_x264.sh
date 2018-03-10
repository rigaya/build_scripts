#!/bin/sh
# msys2用x264ビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=$HOME/build_x264
BUILD_CCFLAGS="-m32 -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include" 
BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -L${INSTALL_DIR}/lib"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
Y4M_PATH="$HOME/husky.y4m"
Y4M_XZ_PATH="$HOME/husky.tar.xz"
X264_MAKEFILE_PATCH="$HOME/patch/x264_makefile.diff"
GOOGLE_DIR="/C/Users/rigaya/GoogleDrive/x264"
ONEDRIVE_DIR="/C/Users/rigaya/OneDrive/x264"
DROPBOX_DIR="/C/Users/rigaya/DropBox/x264"
GPL_LICENSE_PATH="/C/Users/rigaya/GoogleDrive/txt/gplv2.txt"

#download
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src
git config --global core.autocrlf false

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ -d "x264" ]; then
    cd x264
    git pull
    cd ..
else
	git clone git://git.videolan.org/x264.git x264
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
	tar xf $Y4M_XZ_PATH
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

PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
 --prefix=$INSTALL_DIR \
 --host=$MINGW_CHOST \
 --enable-strip \
 --disable-ffms \
 --disable-gpac \
 --bit-depth=all \
 --extra-cflags="-O3 ${BUILD_CCFLAGS}" \
 --extra-ldflags="${BUILD_LDFLAGS}"
make fprofiled VIDS="${Y4M_PATH}" -j$MAKE_PROCESS
cp -f x264.exe x264_${X264_REV}_$TARGET_ARCH.exe


cd $HOME
mkdir -p $BUILD_DIR/temp
mkdir -p $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/x264 $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/l-smash $BUILD_DIR/temp/src
rm -rf $BUILD_DIR/temp/src/x264/.git
rm -rf $BUILD_DIR/temp/src/l-smash/.git

7z a -t7z -mx=9 -mmt=off  "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" $BUILD_DIR/temp/src/

7z a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" $BUILD_DIR/$TARGET_ARCH/x264/x264_${X264_REV}_${TARGET_ARCH}.exe ${GPL_LICENSE_PATH}

read -p "Hit enter: "

cp -f "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" "${GOOGLE_DIR}/src"
cp -f "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" "${DROPBOX_DIR}/src"

cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}"

cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}/old/x264_${X264_REV}_x86.zip"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}/old/x264_${X264_REV}_x86.zip"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}/old/x264_${X264_REV}_x86.zip"

echo ${X264_REV} > "${GOOGLE_DIR}/latest_build.txt"
echo ${X264_REV} > "${ONEDRIVE_DIR}/latest_build.txt"
echo ${X264_REV} > "${DROPBOX_DIR}/latest_build.txt"

rm -rf $BUILD_DIR/temp
