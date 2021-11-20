#!/bin/bash
BUILD_DIR=`pwd`/build_svtav1
BUILD_CCFLAGS="-Ofast -ffast-math -fomit-frame-pointer -flto"
BUILD_LDFLAGS="-static -static-libgcc -flto -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeÇÃÇ†ÇÈèÍèä
CMAKE_DIR="/C/Program Files/CMake/bin"
PROFILE_GEN_CC="-fprofile-generate -fprofile-update=atomic"
PROFILE_GEN_LD="-fprofile-generate -fprofile-update=atomic"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"
YUVFILE="/y/Encoders/sakura_op_short_720p.yuv"
YUVFILE_10="/y/Encoders/sakura_op_short_720p_10.yuv"

export CC=gcc
export CXX=g++
export PATH="${CMAKE_DIR}:$PATH"

#download
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src
git config --global core.autocrlf false

if [ $MSYSTEM != "MINGW64" ]; then
    echo "This script is for mingw64 only!"
    exit 1
else
    TARGET_ARCH="x64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ -d "SVT-AV1" ]; then
    cd SVT-AV1
    git reset --hard HEAD
    git pull
    cd ..
else
    git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git
fi


mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "SVT-AV1" ]; then
    rm -rf SVT-AV1
fi
cp -r ../src/SVT-AV1 SVT-AV1

cd $BUILD_DIR/$TARGET_ARCH/SVT-AV1
mkdir build/msys2
cd build/msys2
cmake -G "MSYS Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DNATIVE=OFF \
  -DENABLE_NASM=ON \
  -DENABLE_AVX512=ON \
  -DCMAKE_ASM_NASM_COMPILER=nasm \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}" \
  ../..

make SvtAv1EncApp -j${NUMBER_OF_PROCESSORS}

../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 4 -n 30 --asm avx512
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 5 -n 30 --asm avx512
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 7 -n 60 --asm avx512
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 4 -n 30 --asm avx2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 5 -n 30 --asm avx2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 7 -n 60 --asm avx2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 4 -n 30 --input-depth 10 --asm avx512
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 5 -n 30 --input-depth 10 --asm avx512
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 7 -n 60 --input-depth 10 --asm avx512
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 4 -n 30 --input-depth 10 --asm avx2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 5 -n 30 --input-depth 10 --asm avx2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 7 -n 60 --input-depth 10 --asm avx2

cmake -G "MSYS Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DNATIVE=OFF \
  -DENABLE_NASM=ON \
  -DENABLE_AVX512=ON \
  -DCMAKE_ASM_NASM_COMPILER=nasm \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}" \
  ../..

make SvtAv1EncApp -j${NUMBER_OF_PROCESSORS}