#!/bin/bash
# pacman -S mingw-w64-clang-x86_64-toolchain
BUILD_DIR=`pwd`/build_svtav1
BUILD_CCFLAGS="-Ofast -ffast-math -fomit-frame-pointer -flto"
BUILD_LDFLAGS="-static -static-libgcc -flto -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeのある場所
CMAKE_DIR="/C/Program Files/CMake/bin"
#PROFILE_GEN_CC="-fprofile-generate -fprofile-update=atomic"
#PROFILE_GEN_LD="-fprofile-generate -fprofile-update=atomic"
PROFILE_GEN_CC="-fprofile-generate -gline-tables-only"
PROFILE_GEN_LD="-fprofile-generate -gline-tables-only"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"
YUVFILE="/y/Encoders/sakura_op_short_720p.yuv"
YUVFILE_10="/y/Encoders/sakura_op_short_720p_10.yuv"
CPUINFO_DIFF=$HOME/patch/svtav1_cpuinfo.diff
BUILD_PSY="FALSE"
if [ $# -gt 0 ] && [ $1 = "-psy" ]; then
    BUILD_PSY="TRUE"
    BUILD_DIR=`pwd`/build_svtav1_psy
fi

export CC=gcc
export CXX=g++
export PATH="${CMAKE_DIR}:$PATH"

PKGCONFIG=pkg-config
CHECK_LIBDOVI_NAMES=dovi
CHECK_LIBHDR10PLUS_NAMES=hdr10plus-rs

#download
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src
git config --global core.autocrlf false

if [ $MSYSTEM != "MINGW64" ] && [ $MSYSTEM != "CLANG64" ]; then
    echo "This script is for mingw64/clang64 only!"
    exit 1
else
    TARGET_ARCH="x64"
    FFMPEG_ARCH="x86_64"
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


if [ $BUILD_PSY = "TRUE" ]; then
    if [ ! -d "dovi_tool-2.1.2" ]; then
        wget -O dovi_tool-2.1.2.tar.gz https://github.com/quietvoid/dovi_tool/archive/refs/tags/2.1.2.tar.gz
        tar xf dovi_tool-2.1.2.tar.gz
    fi
    
    if [ ! -d "hdr10plus_tool-1.6.1" ]; then
        wget -O hdr10plus_tool-1.6.1.tar.gz https://github.com/quietvoid/hdr10plus_tool/archive/refs/tags/1.6.1.tar.gz
        tar xf hdr10plus_tool-1.6.1.tar.gz
    fi
fi

mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "SVT-AV1" ]; then
    rm -rf SVT-AV1
fi
cp -r ../src/SVT-AV1 SVT-AV1

SVTAV1_CMAKE_OPT=
if [ $BUILD_PSY = "TRUE" ]; then
    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "dovi_tool" ]; then
        find ../src/ -type d -name "dovi_tool-*" | xargs -i cp -r {} ./dovi_tool
        cd ./dovi_tool/dolby_vision
        cargo cinstall --target ${FFMPEG_ARCH}-pc-windows-gnu --release --prefix=$INSTALL_DIR
        # dllを削除し、staticライブラリのみを残す
        rm $INSTALL_DIR/lib/dovi.dll.a
        rm $INSTALL_DIR/lib/dovi.def
        rm $INSTALL_DIR/bin/dovi.dll
        # static link向けにdovi.pcを編集
        LIBDOVI_STATIC_LIBS=`awk -F':' '/^Libs.private:/{print $2}' ${INSTALL_DIR}/lib/pkgconfig/dovi.pc`
        sed -i -e "s/-ldovi/-ldovi ${LIBDOVI_STATIC_LIBS}/g" ${INSTALL_DIR}/lib/pkgconfig/dovi.pc

        #dllからlibファイルを作成
        #cd target/x86_64-pc-windows-gnu/release
        #DOVI_DLL_FILENAME=dovi.dll
        #DOVI_DEF_FILENAME=dovi.def
        #DOVI_LIB_FILENAME=$(basename $DOVI_DEF_FILENAME .def).lib
        #lib.exe -machine:$TARGET_ARCH -def:$DOVI_DEF_FILENAME -out:$DOVI_LIB_FILENAME
    fi

    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "hdr10plus_tool" ]; then
        find ../src/ -type d -name "hdr10plus_tool-*" | xargs -i cp -r {} ./hdr10plus_tool
        cd ./hdr10plus_tool/hdr10plus
        cargo cinstall --target ${FFMPEG_ARCH}-pc-windows-gnu --release --prefix=$INSTALL_DIR
        # dllを削除し、staticライブラリのみを残す
        rm $INSTALL_DIR/lib/hdr10plus-rs.dll.a
        rm $INSTALL_DIR/lib/hdr10plus-rs.def
        rm $INSTALL_DIR/bin/hdr10plus-rs.dll
        # static link向けにdovi.pcを編集
        LIBHDR10PLUS_STATIC_LIBS=`awk -F':' '/^Libs.private:/{print $2}' ${INSTALL_DIR}/lib/pkgconfig/hdr10plus-rs.pc`
        sed -i -e "s/-ldovi/-ldovi ${LIBHDR10PLUS_STATIC_LIBS}/g" ${INSTALL_DIR}/lib/pkgconfig/hdr10plus-rs.pc
    fi
    
    export PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig
    LIBDOVI_LIBS=`${PKGCONFIG} --libs ${CHECK_LIBDOVI_NAMES}`
    LIBDOVI_CFLAGS=`${PKGCONFIG} --cflags ${CHECK_LIBDOVI_NAMES}`
    LIBHDR10PLUS_LIBS=`${PKGCONFIG} --libs ${CHECK_LIBHDR10PLUS_NAMES}`
    LIBHDR10PLUS_CFLAGS=`${PKGCONFIG} --cflags ${CHECK_LIBHDR10PLUS_NAMES}`
    BUILD_CCFLAGS="${BUILD_CCFLAGS} ${LIBDOVI_CFLAGS} ${LIBHDR10PLUS_CFLAGS}"
    BUILD_LDFLAGS="${BUILD_LDFLAGS} ${LIBDOVI_LIBS} ${LIBHDR10PLUS_LIBS}"
    SVTAV1_CMAKE_OPT="-DLIBDOVI_FOUND=ON -DLIBHDR10PLUS_RS_FOUND=ON"
fi


cd $BUILD_DIR/$TARGET_ARCH/SVT-AV1
if [ $BUILD_PSY != "TRUE" ]; then
    patch -p1 < $CPUINFO_DIFF
fi
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
  $SVTAV1_CMAKE_OPT \
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
  $SVTAV1_CMAKE_OPT \
  -DCMAKE_ASM_NASM_COMPILER=nasm \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}" \
  ../..

make SvtAv1EncApp -j${NUMBER_OF_PROCESSORS}