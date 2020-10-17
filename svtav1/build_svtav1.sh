BUILD_DIR=`pwd`/build_svtav1
BUILD_CCFLAGS="-Ofast -ffast-math -fomit-frame-pointer -flto"
BUILD_LDFLAGS="-static -static-libgcc -flto -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeÇÃÇ†ÇÈèÍèä
CMAKE_DIR="/C/Program Files/CMake/bin"
PATCH_DIR=$HOME/patch
PROFILE_GEN_CC="-fprofile-generate -fprofile-update=atomic"
PROFILE_GEN_LD="-fprofile-generate -fprofile-update=atomic"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"
YUV_PATH="/Y/QSVTest/sakura_op_8bit_10sec.yuv"
YUV_10_PATH="/Y/QSVTest/sakura_op_10bit_10sec.yuv"

export CC=gcc
export CXX=g++
export PATH="${CMAKE_DIR}:$PATH"

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

if [ -d "SVT-AV1" ]; then
    cd SVT-AV1
    git reset --hard HEAD
    git pull
    cd ..
else
	git clone https://github.com/OpenVisualCloud/SVT-AV1.git
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
  -DENABLE_NASM=ON \
  -DCMAKE_ASM_NASM_COMPILER=yasm \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}" \
  ../..

make SvtAv1EncApp -j$MAKE_PROCESS

../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_PATH}"    --preset 5 -n 30
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_PATH}"    --preset 7 -n 60
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_PATH}"    --preset 5 -n 30 --pass 1 --stats pass.stats --aq-mode 2 --irefresh-type 2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_PATH}"    --preset 5 -n 30 --pass 2 --stats pass.stats --aq-mode 2 --irefresh-type 2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_10_PATH}" --preset 5 -n 30 --input-depth 10
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_10_PATH}" --preset 7 -n 60 --input-depth 10
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_10_PATH}" --preset 5 -n 30 --pass 1 --stats pass.stats --aq-mode 2 --irefresh-type 2 --input-depth 10 --hbd-md 2
../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --qp 30 --fps-num 30 --fps-denom 1 -b /dev/nul -i "${YUV_10_PATH}" --preset 5 -n 30 --pass 2 --stats pass.stats --aq-mode 2 --irefresh-type 2 --input-depth 10 --hbd-md 2

cmake -G "MSYS Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_TESTING=OFF \
  -DENABLE_NASM=ON \
  -DCMAKE_ASM_NASM_COMPILER=yasm \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}" \
  ../..

make SvtAv1EncApp -j$MAKE_PROCESS