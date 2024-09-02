#!/bin/sh
#msys2用x265ビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain p7zip git nasm p7zip
#そのほかにcmakeのインストールが必要
NJOBS=$(($NUMBER_OF_PROCESSORS>16?16:$NUMBER_OF_PROCESSORS))
BUILD_DIR=$HOME/build_x265
BUILD_DIR_WIN=`cygpath -m ${HOME}`/build_x265
#cmake.exeのある場所
CMAKE_DIR="/C/Program Files/CMake/bin"
#プロファイル用のソース
Y4M_PATH=$HOME/sakura_op_cut.y4m

X265_REV=
X265_BRANCH="master"
UPDATE_X265="TRUE"
BUILD_12BIT="ON"
BUILD_10BIT="ON"
PROFILE_GEN_CC="-fprofile-generate"
PROFILE_GEN_LD="-fprofile-generate"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"

export PATH="${CMAKE_DIR}:$PATH"

mkdir -p ${BUILD_DIR}
mkdir -p ${BUILD_DIR}/src
cd ${BUILD_DIR}/src

# [ "x86", "x64" ]
if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi
echo "TARGET_ARCH=${TARGET_ARCH}"

if [ ${TARGET_ARCH} = "x64" ]; then
    BUILD_CCFLAGS="-O3 -msse2 -fpermissive -flto -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-static -static-libgcc -static-libstdc++ -flto -L${INSTALL_DIR}/lib"
elif [ ${TARGET_ARCH} = "x86" ]; then
    BUILD_CCFLAGS="-m32 -msse2 -I${INSTALL_DIR}/include" 
    BUILD_LDFLAGS="-static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
    #x86向けには高ビット深度版はビルドしない
    BUILD_12BIT="OFF"
    BUILD_10BIT="OFF"
    #x86向けには、プロファイル最適化はスキップする
    PROFILE_GEN_CC=""
    PROFILE_GEN_LD=""
    PROFILE_USE_CC=""
    PROFILE_USE_LD=""
else
    echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
    exit
fi

#--- ソースのダウンロード ---------------------------------------
if [ -d "x265" ]; then
    if [ $UPDATE_X265 != "FALSE" ]; then
        cd x265
        if [ "${X265_REV}" != "" ]; then
            git fetch && git checkout --force ${X265_REV}
        else
            git fetch && git checkout --force ${X265_BRANCH} && git reset --hard origin/${X265_BRANCH}
        fi
        cd ..
    fi
else
    UPDATE_X265=TRUE
    git clone https://bitbucket.org/multicoreware/x265_git.git x265
    cd x265
    git fetch
    if [ "${X265_REV}" != "" ]; then
        git checkout --force ${X265_REV}
    else
        git checkout --force ${X265_BRANCH}
        git reset --hard origin/${X265_BRANCH}
    fi
    cd ..
fi

# --- 出力先を準備 --------------------------------------
if [ ! -d ${BUILD_DIR}/${TARGET_ARCH} ]; then
    mkdir ${BUILD_DIR}/${TARGET_ARCH}
fi
cd ${BUILD_DIR}/${TARGET_ARCH}
if [ -d x265 ]; then
    rm -rf x265
fi
cp -r ../src/x265 .


# --- ビルド ----------------------------------------------
cd ${BUILD_DIR}/${TARGET_ARCH}/x265
patch -p 1 < ~/patch/x265_version.diff
patch -p 1 < ~/patch/x265_zone_param.diff

cd ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys

X265_EXTRA_LIB=""

mkdir -p 8bit

if [ "${PROFILE_GEN_CC}" != "" ]; then

    CMAKE_PROFILE_ARG="-DFPROFILE_GENERATE=ON"

    if [ $BUILD_12BIT = "ON" ]; then
        mkdir -p 12bit
        cd 12bit
        #fprofile-generateするためには、-fprofile-generateを
        #CMAKE_C_FLAGS/CMAKE_CXX_FLAGSだけでなく、CMAKE_EXE_LINKER_FLAGSに渡す必要がある
        cmake -G "MSYS Makefiles" ../../../source \
            -DHIGH_BIT_DEPTH=ON \
            -DEXPORT_C_API=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_HDR10_PLUS=OFF \
            -DENABLE_CLI=OFF \
            -DMAIN12=ON \
            ${CMAKE_PROFILE_ARG} \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"
        make -j${NJOBS} &
        X265_EXTRA_LIB="x265_main12"
    fi

    cd ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys
    if [ $BUILD_10BIT = "ON" ]; then
        mkdir -p 10bit
        cd 10bit
        #fprofile-generateするためには、-fprofile-generateを
        #CMAKE_C_FLAGS/CMAKE_CXX_FLAGSだけでなく、CMAKE_EXE_LINKER_FLAGSに渡す必要がある
        cmake -G "MSYS Makefiles" ../../../source \
            -DHIGH_BIT_DEPTH=ON \
            -DEXPORT_C_API=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_HDR10_PLUS=ON \
            -DENABLE_CLI=OFF \
            ${CMAKE_PROFILE_ARG} \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"
        make -j${NJOBS} &
        X265_EXTRA_LIB="x265_main10;${X265_EXTRA_LIB}"
    fi

    cd ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit
	if [ $BUILD_10BIT = "ON" ] || [ $BUILD_12BIT = "ON" ]; then
		wait
		if [ $BUILD_10BIT = "ON" ]; then
			cp ../10bit/libx265.a libx265_main10.a
		fi
		if [ $BUILD_12BIT = "ON" ]; then
			cp ../12bit/libx265.a libx265_main12.a
		fi
	fi
    cmake -G "MSYS Makefiles" ../../../source \
        -DEXTRA_LIB="${X265_EXTRA_LIB}" \
        -DEXTRA_LINK_FLAGS=-L. \
        -DLINKED_10BIT=${BUILD_10BIT} \
        -DLINKED_12BIT=${BUILD_12BIT} \
        -DENABLE_SHARED=OFF \
        -DENABLE_HDR10_PLUS=OFF \
        ${CMAKE_PROFILE_ARG} \
        -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
        -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
        -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"

    #強制的に完全な静的リンクにする
    sed -i -e 's/Bdynamic/Bstatic/g' CMakeFiles/cli.dir/linklibs.rsp
    make -j${NJOBS}

    #profileのための実行はシングルスレッドで行う
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --preset faster
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --preset fast
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}"
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --preset slow
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --preset slower
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 10 --preset faster
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 10 --preset fast
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 10
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 10 --preset slow
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 10 --preset slower
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 12 --preset faster
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 12 --preset fast
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 12
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 12 --preset slow
    ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/nul --input "${Y4M_PATH}" --output-depth 12 --preset slower

fi


if [ "${PROFILE_GEN_CC}" = "" ]; then
    CMAKE_PROFILE_ARG=""
else
    CMAKE_PROFILE_ARG="-DFPROFILE_GENERATE=OFF -DFPROFILE_USE=ON"
fi

X265_EXTRA_LIB=""

cd ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys
if [ $BUILD_12BIT = "ON" ]; then
    mkdir -p 12bit
    cd 12bit
    cmake -G "MSYS Makefiles" ../../../source \
        -DHIGH_BIT_DEPTH=ON \
        -DEXPORT_C_API=OFF \
        -DENABLE_SHARED=OFF \
        -DENABLE_HDR10_PLUS=OFF \
        -DENABLE_CLI=OFF \
        -DMAIN12=ON \
        ${CMAKE_PROFILE_ARG} \
        -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
        -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
        -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}"
    make -j${NJOBS} &
    cp libx265.a ../8bit/libx265_main12.a
    X265_EXTRA_LIB="x265_main12"
fi

cd ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys
if [ $BUILD_10BIT = "ON" ]; then
    mkdir -p 10bit
    cd 10bit
    cmake -G "MSYS Makefiles" ../../../source \
        -DHIGH_BIT_DEPTH=ON \
        -DEXPORT_C_API=OFF \
        -DENABLE_SHARED=OFF \
        -DENABLE_HDR10_PLUS=ON \
        -DENABLE_CLI=OFF \
        ${CMAKE_PROFILE_ARG} \
        -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
        -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
        -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}"
    make -j${NJOBS} &
    cp libx265.a ../8bit/libx265_main10.a
    X265_EXTRA_LIB="x265_main10;${X265_EXTRA_LIB}"
fi

cd ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit
if [ $BUILD_10BIT = "ON" ] || [ $BUILD_12BIT = "ON" ]; then
	wait
	if [ $BUILD_10BIT = "ON" ]; then
		cp ../10bit/libx265.a libx265_main10.a
	fi
	if [ $BUILD_12BIT = "ON" ]; then
		cp ../12bit/libx265.a libx265_main12.a
	fi
fi
cmake -G "MSYS Makefiles" ../../../source \
    -DEXTRA_LIB="${X265_EXTRA_LIB}" \
    -DEXTRA_LINK_FLAGS=-L. \
    -DLINKED_10BIT=${BUILD_10BIT} \
    -DLINKED_12BIT=${BUILD_12BIT} \
    -DENABLE_SHARED=OFF \
    -DENABLE_HDR10_PLUS=OFF \
    ${CMAKE_PROFILE_ARG} \
    -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
    -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
    -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}"

#強制的に完全な静的リンクにする
sed -i -e 's/Bdynamic/Bstatic/g' CMakeFiles/cli.dir/linklibs.rsp
#echo ${SVT_HEVC_LINK_LIBS} >> CMakeFiles/cli.dir/linklibs.rsp
make -j${NJOBS}

strip -s ${BUILD_DIR}/${TARGET_ARCH}/x265/build/msys/8bit/x265.exe
