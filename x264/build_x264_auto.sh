#!/bin/sh
# msys2用x264ビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=`pwd`/build_x264
GOOGLE_DIR="/C/Users/rigaya/GoogleDrive/x264"
ONEDRIVE_DIR="/C/Users/rigaya/OneDrive/x264"
DROPBOX_DIR="/C/Users/rigaya/DropBox/x264"
GPL_LICENSE_PATH="/C/Users/rigaya/GoogleDrive/txt/gplv2.txt"

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi

. ./build_x264.sh

echo target=${X264_REV}_${TARGET_ARCH}

cd $BUILD_DIR
mkdir -p $BUILD_DIR/temp
mkdir -p $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/x264 $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/l-smash $BUILD_DIR/temp/src
rm -rf $BUILD_DIR/temp/src/x264/.git
rm -rf $BUILD_DIR/temp/src/l-smash/.git

7z a -t7z -mx=9 -mmt=off  "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" $BUILD_DIR/temp/src/

7z a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" $BUILD_DIR/$TARGET_ARCH/x264/x264_${X264_REV}_${TARGET_ARCH}.exe ${GPL_LICENSE_PATH}

cp -f "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" "${GOOGLE_DIR}/src"
cp -f "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "$BUILD_DIR/temp/x264_${X264_REV}_src.7z" "${DROPBOX_DIR}/src"

cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}"

cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}/old/x264_${X264_REV}_${TARGET_ARCH}.zip"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}/old/x264_${X264_REV}_${TARGET_ARCH}.zip"
cp -f "$BUILD_DIR/temp/x264_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}/old/x264_${X264_REV}_${TARGET_ARCH}.zip"

echo ${X264_REV} > "${GOOGLE_DIR}/latest_build.txt"
echo ${X264_REV} > "${ONEDRIVE_DIR}/latest_build.txt"
echo ${X264_REV} > "${DROPBOX_DIR}/latest_build.txt"

