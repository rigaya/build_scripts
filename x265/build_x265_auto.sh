#!/bin/sh
BUILD_DIR=$HOME/build_x265
#cmake.exe‚Ì‚ ‚éêŠ
CMAKE_DIR="/C/Program Files/CMake/bin"
#hg.exe‚Ì‚ ‚éêŠ
HG_DIR="/C/Program Files/Mercurial"
#“¯ŠúƒtƒHƒ‹ƒ_
GOOGLE_DIR="/C/Users/rigaya/GoogleDrive/x265"
ONEDRIVE_DIR="/C/Users/rigaya/OneDrive/x265"
DROPBOX_DIR="/C/Users/rigaya/DropBox/x265"
GPL_LICENSE_PATH="/C/Users/rigaya/GoogleDrive/txt/gplv2.txt"

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi

export PATH="${CMAKE_DIR}:${HG_DIR}:$PATH"

./build_x265.sh

cd $BUILD_DIR/src/x265
X265_VER=`hg log -r. --template "{latesttag}"`
X265_VER=${X265_VER}+`hg log -r. --template "{latesttagdistance}"`
echo "build x265 ${X265_VER}"

mkdir $BUILD_DIR/temp
cp -r $BUILD_DIR/src/x265 $BUILD_DIR/temp/src
rm -rf $BUILD_DIR/temp/src/.hg

7z a -t7z -mx=9 -mmt=off "$BUILD_DIR/temp/x265_${X265_VER}_src.7z" $BUILD_DIR/temp/src/

cp -f $BUILD_DIR/$TARGET_ARCH/x265/build/msys/8bit/x265.exe $BUILD_DIR/$TARGET_ARCH/x265/build/msys/8bit/x265_${X265_VER}_${TARGET_ARCH}.exe
7z a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" $BUILD_DIR/$TARGET_ARCH/x265/build/msys/8bit/x265_${X265_VER}_${TARGET_ARCH}.exe ${GPL_LICENSE_PATH}

rm -f "${GOOGLE_DIR}"/current*.txt
rm -f "${ONEDRIVE_DIR}"/current*.txt
rm -f "${DROPBOX_DIR}"/current*.txt

echo -n > "${GOOGLE_DIR}/current version is ${X265_VER}.txt"
echo -n > "${ONEDRIVE_DIR}/current version is ${X265_VER}.txt"
echo -n > "${DROPBOX_DIR}/current version is ${X265_VER}.txt"

cp -f "$BUILD_DIR/temp/x265_${X265_VER}_src.7z" "${GOOGLE_DIR}/src"
cp -f "$BUILD_DIR/temp/x265_${X265_VER}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "$BUILD_DIR/temp/x265_${X265_VER}_src.7z" "${DROPBOX_DIR}/src"

cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}"
cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}"
cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}"

if [ $TARGET_ARCH = "x64" ]; then
    cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}/x265_latest_${TARGET_ARCH}_pgo.zip"
    cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}/x265_latest_${TARGET_ARCH}_pgo.zip"
    cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}/x265_latest_${TARGET_ARCH}_pgo.zip"
fi

cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${GOOGLE_DIR}/old/x265_${X265_VER}_${TARGET_ARCH}.zip"
cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}/old/x265_${X265_VER}_${TARGET_ARCH}.zip"
# cp -f "$BUILD_DIR/temp/x265_latest_${TARGET_ARCH}.zip" "${DROPBOX_DIR}/old/x265_${X265_VER}_${TARGET_ARCH}.zip"

echo ${X265_VER} > "${GOOGLE_DIR}/latest_build.txt"
echo ${X265_VER} > "${ONEDRIVE_DIR}/latest_build.txt"
echo ${X265_VER} > "${DROPBOX_DIR}/latest_build.txt"

rm -rf $BUILD_DIR/temp
