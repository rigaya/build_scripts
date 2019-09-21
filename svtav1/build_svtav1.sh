BUILD_DIR=`pwd`/build_svtav1
BUILD_CCFLAGS="-ffast-math -fomit-frame-pointer -fno-ident"
BUILD_LDFLAGS="-static -static-libgcc -Wl,--gc-sections -Wl,--strip-all"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
#cmake.exeÇÃÇ†ÇÈèÍèä
CMAKE_DIR="/C/Program Files/CMake/bin"
PATCH_DIR=$HOME/patch

export CC=clang
export CXX=clang++
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

# ./build.sh -p$INSTALL_DIR -x -j$MAKE_PROCESS -sWindows
cd $BUILD_DIR/$TARGET_ARCH/SVT-AV1
patch -p1 < $PATCH_DIR/svtav1_msys2.diff
mkdir build/msys2
cd build/msys2
cmake -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_ASM_NASM_COMPILER=yasm -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_C_FLAGS="${BUILD_CCFLAGS}" -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS}" ../..
make SvtAv1EncApp -j8