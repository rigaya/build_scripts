# mingw-w64-x86_64-llvm, mingw-w64-x86_64-compiler-rt
BUILD_DIR=`pwd`/build_vvenc
BUILD_CCFLAGS="-Ofast -ffast-math -fomit-frame-pointer -w"
BUILD_LDFLAGS="-static -static-libgcc -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeÇÃÇ†ÇÈèÍèä
CMAKE_DIR="/C/Program Files/CMake/bin"
PATCH_DIR=$HOME/patch

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

if [ -d "vvenc" ]; then
    cd vvenc
    git reset --hard HEAD
    git pull
    cd ..
else
    git clone https://github.com/fraunhoferhhi/vvenc.git vvenc
fi


mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "vvenc" ]; then
    rm -rf vvenc
fi
cp -r ../src/vvenc vvenc

cd $BUILD_DIR/$TARGET_ARCH/vvenc
mkdir build
cd build
cmake -G "MSYS Makefiles" \
  -DCMAKE_BUILD_TYPE=Release \
  -DVVENC_ENABLE_LINK_TIME_OPT=OFF \
  -DVVENC_INSTALL_FULLFEATURE_APP=ON \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
  -DCMAKE_C_FLAGS="${BUILD_CCFLAGS}" \
  -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS}" \
  -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS}" \
  ..

make -j$MAKE_PROCESS