#!/bin/sh
BUILD_DIR=$HOME/build_x265
#cmake.exe‚Ì‚ ‚éêŠ
CMAKE_DIR="/C/Program Files/CMake/bin"
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

export PATH="${CMAKE_DIR}:$PATH"

./build_x265.sh

X265_VER=`${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit/x265.exe --version 2>&1 | head -n 1 | sed 's/-/ /g' | awk '{print $6}'`

cd ${BUILD_DIR}/src/x265
echo "build x265 ${X265_VER}"

mkdir ${BUILD_DIR}/temp
cp -r ${BUILD_DIR}/src/x265 ${BUILD_DIR}/temp/src
rm -rf ${BUILD_DIR}/temp/src/x265/.git

7z a -t7z -mx=9 -mmt=off "${BUILD_DIR}/temp/x265_${X265_VER}_src.7z" ${BUILD_DIR}/temp/src/x265

cp -f ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit/x265.exe ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit/x265_${X265_VER}_${TARGET_ARCH}.exe
7z a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit/x265_${X265_VER}_${TARGET_ARCH}.exe ${GPL_LICENSE_PATH}

cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_src.7z" "${GOOGLE_DIR}/src"
cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_src.7z" "${DROPBOX_DIR}/src"

rm ${GOOGLE_DIR}/x265_*_${TARGET_ARCH}.zip
rm ${ONEDRIVE_DIR}/x265_*_${TARGET_ARCH}.zip
rm ${DROPBOX_DIR}/x265_*_${TARGET_ARCH}.zip

cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" "${GOOGLE_DIR}"
cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}"
cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" "${DROPBOX_DIR}"

cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" "${GOOGLE_DIR}/old/x265_${X265_VER}_${TARGET_ARCH}.zip"
cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}/old/x265_${X265_VER}_${TARGET_ARCH}.zip"
# cp -f "${BUILD_DIR}/temp/x265_${X265_VER}_${TARGET_ARCH}.zip" "${DROPBOX_DIR}/old/x265_${X265_VER}_${TARGET_ARCH}.zip"

# rm -rf ${BUILD_DIR}/temp
