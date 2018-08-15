#!/bin/sh
# msys2用x264afsビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=`pwd`/build_x264
GOOGLE_DIR="/C/Users/rigaya/GoogleDrive/x264afs"
ONEDRIVE_DIR="/C/Users/rigaya/OneDrive/x264afs"
DROPBOX_DIR="/C/Users/rigaya/DropBox/x264afs"
GPL_LICENSE_PATH="/C/Users/rigaya/GoogleDrive/txt/gplv2.txt"
BUILD_ALL=1

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi

. ./build_x264afs.sh

echo target=${X264_REV}+${LSMASH_REV}_${TARGET_ARCH}

cd $HOME
mkdir -p $BUILD_DIR/temp
mkdir -p $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/x264 $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/ffmpeg $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/l-smash $BUILD_DIR/temp/src
rm -rf $BUILD_DIR/temp/src/x264/.git
rm -rf $BUILD_DIR/temp/src/ffmpeg/.git
rm -rf $BUILD_DIR/temp/src/l-smash/.git

7z a -t7z -mx=9 -mmt=off  "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" $BUILD_DIR/temp/src/

7z a -t7z -mx=9 -mmt=off "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" $BUILD_DIR/$TARGET_ARCH/x264afs/x264afs_r${X264_REV}+${LSMASH_REV}.exe ${GPL_LICENSE_PATH}

cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" "${GOOGLE_DIR}/src"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" "${DROPBOX_DIR}/src"

cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" "${GOOGLE_DIR}"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" "${ONEDRIVE_DIR}"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" "${DROPBOX_DIR}"

rm -rf $BUILD_DIR/temp
