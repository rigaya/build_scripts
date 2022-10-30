# mingw-w64-x86_64-llvm, mingw-w64-x86_64-compiler-rt
BUILD_DIR=`pwd`/build_vvdec
BUILD_CCFLAGS="-Ofast -ffast-math -fomit-frame-pointer -w"
BUILD_LDFLAGS="-static -static-libgcc -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeÇÃÇ†ÇÈèÍèä
CMAKE_DIR="/C/Program Files/CMake/bin"
PATCH_DIR=$HOME/patch
PROFILE_GEN_CC="-fprofile-generate -fprofile-update=atomic"
PROFILE_GEN_LD="-fprofile-generate -fprofile-update=atomic"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"
YUV_PATH="/C/ProgramEx/sakura_op_8bit_10sec.yuv"
YUV_10_PATH="/C/ProgramEx/sakura_op_10bit_10sec.yuv"

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

if [ -d "vvdec" ]; then
    cd vvdec
    git reset --hard HEAD
    git pull
    cd ..
else
	git clone https://github.com/fraunhoferhhi/vvdec.git
fi


mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "vvdec" ]; then
    rm -rf vvdec
fi
cp -r ../src/vvdec vvdec

cd $BUILD_DIR/$TARGET_ARCH/vvdec
mkdir build
cd build
cmake -G "MSYS Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DVVDEC_ENABLE_LINK_TIME_OPT=OFF \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS}" \
  ..

make -j$MAKE_PROCESS