#!/bin/sh
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=`pwd`/build_svtav1
GOOGLE_DIR="/C/Users/rigaya/GoogleDrive/svtav1"
ONEDRIVE_DIR="/C/Users/rigaya/OneDrive/svtav1"
DROPBOX_DIR="/C/Users/rigaya/DropBox/svtav1"

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi

EXE_NAME=SvtAv1EncApp
ARCHIEVE_NAME=svtav1
if [ $1 = "-psy" ]; then
    BUILD_PSY="TRUE"
    BUILD_DIR=`pwd`/build_svtav1_psy
    EXE_NAME="${EXE_NAME}Psy"
    ARCHIEVE_NAME="${ARCHIEVE_NAME}_psy"
fi

. ./build_svtav1.sh $1


EXE_PATH_ORG=$BUILD_DIR/$TARGET_ARCH/SVT-AV1/Bin/Release/SvtAv1EncApp.exe
if [ $BUILD_PSY = "TRUE" ]; then
    SVTAV1_REV=`${EXE_PATH_ORG} --version | cut -d ' ' -f 2 | head -1`
else
    SVTAV1_REV=`${EXE_PATH_ORG} --version | cut -d ' ' -f 2`
    SVTAV1_REV=${SVTAV1_REV:1:-10}
fi

EXE_PATH=$BUILD_DIR/$TARGET_ARCH/SVT-AV1/Bin/Release/${EXE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.exe
cp ${EXE_PATH_ORG} ${EXE_PATH}

echo target=${SVTAV1_REV}_${TARGET_ARCH}

cd $BUILD_DIR
mkdir -p $BUILD_DIR/temp
mkdir -p $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/SVT-AV1 $BUILD_DIR/temp/src
rm -rf $BUILD_DIR/temp/src/SVT-AV1/.git $BUILD_DIR/temp/src/SVT-AV1/.gitlab $BUILD_DIR/temp/src/SVT-AV1/Docs

7z a -t7z -mx=9 -mmt=off  "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_src.7z" $BUILD_DIR/temp/src/

7z a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" ${EXE_PATH}

cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_src.7z" "${GOOGLE_DIR}/src"
cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_src.7z" "${DROPBOX_DIR}/src"

rm ${GOOGLE_DIR}/${ARCHIEVE_NAME}_*_${TARGET_ARCH}.zip
rm ${ONEDRIVE_DIR}/${ARCHIEVE_NAME}_*_${TARGET_ARCH}.zip
rm ${DROPBOX_DIR}/${ARCHIEVE_NAME}_*_${TARGET_ARCH}.zip

cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" "${GOOGLE_DIR}"
cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}"
cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" "${DROPBOX_DIR}"

cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" "${GOOGLE_DIR}/old/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip"
cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" "${ONEDRIVE_DIR}/old/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip"
cp -f "$BUILD_DIR/temp/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip" "${DROPBOX_DIR}/old/${ARCHIEVE_NAME}_${SVTAV1_REV}_${TARGET_ARCH}.zip"
