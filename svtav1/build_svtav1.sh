#!/bin/bash
BUILD_DIR=`pwd`/build_svtav1
BUILD_CCFLAGS="-Ofast -ffast-math -fomit-frame-pointer -flto"
BUILD_LDFLAGS="-static -static-libgcc -flto -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeÇÃÇ†ÇÈèÍèä
CMAKE_DIR="/C/Program Files/CMake/bin"
#PROFILE_GEN_CC="-fprofile-generate -fprofile-update=atomic"
#PROFILE_GEN_LD="-fprofile-generate -fprofile-update=atomic"
PROFILE_GEN_CC="-fprofile-generate -gline-tables-only"
PROFILE_GEN_LD="-fprofile-generate -gline-tables-only"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"
YUVFILE="/y/Encoders/sakura_op_short_720p.yuv"
YUVFILE_10="/y/Encoders/sakura_op_short_720p_10.yuv"
BUILD_PSY="FALSE"
if [ $1 = "-psy" ]; then
    BUILD_PSY="TRUE"
    BUILD_DIR=`pwd`/build_svtav1_psy
fi

export CC=gcc
export CXX=g++
export PATH="${CMAKE_DIR}:$PATH"

#download
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src
git config --global core.autocrlf false

if [ $MSYSTEM != "MINGW64" ] && [ $MSYSTEM != "CLANG64" ]; then
    echo "This script is for mingw64/clang64 only!"
    exit 1
else
    TARGET_ARCH="x64"
fi

if [ $MSYSTEM == "CLANG64" ]; then
    export CC=clang
    export CXX=clang++
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ -d "SVT-AV1" ]; then
    cd SVT-AV1
    git reset --hard HEAD
    git pull
    cd ..
else
    if [ $BUILD_PSY = "TRUE" ]; then
        git clone https://github.com/gianni-rosato/svt-av1-psy.git SVT-AV1
    else
        git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git
    fi
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
  -DSVT_AV1_LTO=ON \
  -DENABLE_NASM=ON \
  -DENABLE_AVX512=ON \
  -DCMAKE_ASM_NASM_COMPILER=nasm \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}" \
  ../..

make SvtAv1EncApp -j${NUMBER_OF_PROCESSORS}


prof_files=()
prof_idx=0

function run_prof() {
	../../Bin/Release/SvtAv1EncApp.exe $@
	prof_idx=$((prof_idx + 1))
	for file in default_*_0.profraw; do
	  new_file="${file%.profraw}_${prof_idx}.${file##*.}"
	  mv "$file" "$new_file"
	  echo ${new_file}
	  prof_files+=( ${new_file} )
	done
}

run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  2 -n 30 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  4 -n 30 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  6 -n 30 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  8 -n 60 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 12 -n 60 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  2 -n 30 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  4 -n 30 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  6 -n 30 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset  8 -n 60 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 12 -n 60 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  2 -n 30 --input-depth 10 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  4 -n 30 --input-depth 10 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  6 -n 30 --input-depth 10 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  8 -n 60 --input-depth 10 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 12 -n 60 --input-depth 10 --asm avx512
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  2 -n 30 --input-depth 10 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  4 -n 30 --input-depth 10 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  6 -n 30 --input-depth 10 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset  8 -n 60 --input-depth 10 --asm avx2
run_prof -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 12 -n 60 --input-depth 10 --asm avx2

echo ${prof_files[@]}
llvm-profdata merge -output=default.profdata "${prof_files[@]}"

PROFILE_USE_CC=${PROFILE_USE_CC}=`pwd`/default.profdata
PROFILE_USE_LD=${PROFILE_USE_LD}=`pwd`/default.profdata

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