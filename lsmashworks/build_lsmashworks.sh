#!/bin/bash
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools autogen
#pacman -S p7zip git nasm yasm python unzip
#pacman -S mingw32/mingw-w64-i686-cmake mingw64/mingw-w64-x86_64-cmake
#pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson

NJOBS=$NUMBER_OF_PROCESSORS
PATCHES_DIR=$HOME/patches

BUILD_DIR=$HOME/build_lsmashworks

BUILD_ALL="FALSE"
UPDATE_FFMPEG="FALSE"
UPDATE_LSMASHWORKS="FALSE"
ENABLE_DEBUG="FALSE"

while getopts ":-:d" key; do
  if [[ $key == - ]]; then
    key=${OPTARG}
    keyarg=${!OPTIND}
  fi

  case $key in
    d | enable-debug )
      ENABLE_DEBUG="TRUE"
      ;;
    update-ffmpeg )
      UPDATE_FFMPEG="TRUE"
      ;;
    update-lsw )
      UPDATE_LSMASHWORKS="TRUE"
      ;;
  esac

  while [[ -n ${!OPTIND} && ${!OPTIND} != -* ]]; do
      args+=(${!OPTIND})
      OPTIND=$((OPTIND + 1))
  done
done

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
    VC_ARCH="win32"
    FFMPEG_ARCH="i686"
    MINGWDIR="mingw32"
else
    TARGET_ARCH="x64"
    VC_ARCH="x64"
    FFMPEG_ARCH="x86_64"
    MINGWDIR="mingw64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build


if [ $TARGET_ARCH = "x64" ]; then
    BUILD_CCFLAGS="-D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
elif [ $TARGET_ARCH = "x86" ]; then
    BUILD_CCFLAGS="-m32 -D_FORTIFY_SOURCE=0 -mstackrealign -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
    #  libavcodec/h264_cabac.c: In function 'ff_h264_decode_mb_cabac': libavcodec/x86/cabac.h:192:5: error: 'asm' operand has impossible 対策
    # FFMPEG_DISABLE_ASM="--disable-inline-asm"
else
    echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
    exit
fi

if [ $ENABLE_DEBUG = "TRUE" ]; then
    BUILD_CCFLAGS="${BUILD_CCFLAGS} -O0 -g"
    BUILD_LDFLAGS="${BUILD_LDFLAGS} -O0 -g"
else
    #BUILD_CCFLAGS="${BUILD_CCFLAGS} -O3 -ffunction-sections -fno-ident -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer"
    #BUILD_CCFLAGS="${BUILD_CCFLAGS} -O2 -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer"
    #BUILD_CCFLAGS="${BUILD_CCFLAGS} -O2 -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math"
    BUILD_CCFLAGS="${BUILD_CCFLAGS} -O3 -ffunction-sections -fno-ident -msse2 -mfpmath=sse -fomit-frame-pointer"
    BUILD_LDFLAGS="${BUILD_LDFLAGS} -Wl,--gc-sections -Wl,--strip-all"
fi

FFMPEG_DIR_NAME="ffmpeg"

echo BUILD_DIR=$BUILD_DIR
echo INSTALL_DIR=$INSTALL_DIR
echo UPDATE_FFMPEG=$UPDATE_FFMPEG
echo UPDATE_LSMASHWORKS=$UPDATE_LSMASHWORKS


mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src

#--- ソースのダウンロード ---------------------------------------
if [ ! -d "L-SMASH-Works" ]; then
    UPDATE_LSMASHWORKS="TRUE"
    #git clone https://github.com/HomeOfAviSynthPlusEvolution/L-SMASH-Works.git L-SMASH-Works
    #git clone https://github.com/rigaya/L-SMASH-Works.git L-SMASH-Works
    git clone https://github.com/Mr-Ojii/L-SMASH-Works.git L-SMASH-Works
elif [ $UPDATE_LSMASHWORKS = "TRUE" ]; then
    cd L-SMASH-Works
    git fetch
    git reset --hard origin/master
    cd ..
fi

if [ ! -d "ffmpeg" ]; then
    UPDATE_FFMPEG=TRUE
fi
if [ $UPDATE_FFMPEG = "TRUE" ]; then
    if [ -d "ffmpeg" ]; then
        rm -rf ffmpeg
    fi
    FFMPEG_ARCHIEVE_VER=ffmpeg-8.0
    if [ ! -e ${FFMPEG_ARCHIEVE_VER}.tar.xz ]; then
        wget https://ffmpeg.org/releases/${FFMPEG_ARCHIEVE_VER}.tar.xz
    fi
    tar xf ${FFMPEG_ARCHIEVE_VER}.tar.xz
    mv ${FFMPEG_ARCHIEVE_VER} ffmpeg
    #wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
    #tar xf ffmpeg-snapshot.tar.bz2
fi

if [ ! -d "l-smash" ]; then
    git clone https://github.com/rigaya/l-smash l-smash
else
    cd l-smash
    git fetch
    git reset --hard origin/master
    cd ..
fi

if [ ! -d "zlib-1.3.1" ]; then
    wget https://www.zlib.net/zlib-1.3.1.tar.xz
    tar xf zlib-1.3.1.tar.xz
fi

if [ ! -d "bzip2-1.0.8" ]; then
    wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
    tar xf bzip2-1.0.8.tar.gz
fi

if [ ! -d "libiconv-1.16" ]; then
    wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz
    tar xf libiconv-1.16.tar.gz
fi

if [ ! -d "libogg-1.3.6" ]; then
    wget https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz
    tar xf libogg-1.3.6.tar.xz
fi

if [ ! -d "libvorbis-1.3.7" ]; then
    wget https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz
    tar xf libvorbis-1.3.7.tar.xz
fi

if [ ! -d "opus-1.5.2" ]; then
    wget https://downloads.xiph.org/releases/opus/opus-1.5.2.tar.gz
    tar xf opus-1.5.2.tar.gz
fi

if [ ! -d "libvpl-2.15.0" ]; then
    wget -O libvpl-2.15.0.tar.gz https://github.com/intel/libvpl/archive/refs/tags/v2.15.0.tar.gz
    tar xf libvpl-2.15.0.tar.gz
fi

if [ ! -d "nv-codec-headers-12.2.72.0" ]; then
    wget https://github.com/FFmpeg/nv-codec-headers/releases/download/n12.2.72.0/nv-codec-headers-12.2.72.0.tar.gz
    tar xf nv-codec-headers-12.2.72.0.tar.gz
fi

if [ ! -d "libvpx-1.15.2" ]; then
    wget -O libvpx-1.15.2.tar.gz https://github.com/webmproject/libvpx/archive/refs/tags/v1.15.2.tar.gz
    tar xf libvpx-1.15.2.tar.gz
fi

if [ ! -d "dav1d-1.5.1" ]; then
    wget https://code.videolan.org/videolan/dav1d/-/archive/1.5.1/dav1d-1.5.1.tar.gz
    tar xf dav1d-1.5.1.tar.gz
fi

if [ ! -d "AviSynthPlus-3.7.3" ]; then
    wget -O AviSynthPlus-v3.7.3.tar.gz https://github.com/AviSynth/AviSynthPlus/archive/refs/tags/v3.7.3.tar.gz
    tar xf AviSynthPlus-v3.7.3.tar.gz
fi

if [ ! -d "zimg-3.0.6" ]; then
    wget -O zimg-release-3.0.6.tar.gz https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz
    tar xf zimg-release-3.0.6.tar.gz
    mv zimg-release-3.0.6 zimg-3.0.6
fi

if [ ! -d "vapoursynth-R69" ]; then
    wget -O vapoursynth-R69.tar.gz https://github.com/vapoursynth/vapoursynth/archive/refs/tags/R69.tar.gz
    tar xf vapoursynth-R69.tar.gz
fi

# --- 出力先を準備 --------------------------------------
if [ $BUILD_ALL != "FALSE" ]; then
    rm -rf $BUILD_DIR/$TARGET_ARCH
fi

if [ ! -d $BUILD_DIR/$TARGET_ARCH ]; then
    mkdir $BUILD_DIR/$TARGET_ARCH
fi
cd $BUILD_DIR/$TARGET_ARCH
# --- 出力先の古いデータを削除 ----------------------
if [ ! -d L-SMASH-Works ]; then
    UPDATE_LSMASHWORKS="TRUE"
fi
if [ $UPDATE_LSMASHWORKS = "TRUE" ]; then
    if [ -d L-SMASH-Works ]; then
        rm -rf L-SMASH-Works
    fi
    cp -r ../src/L-SMASH-Works .
fi

if [ ! -d $FFMPEG_DIR_NAME ]; then
    UPDATE_FFMPEG="TRUE"
fi
if [ $UPDATE_FFMPEG != "FALSE" ]; then
    if [ -d $FFMPEG_DIR_NAME ]; then
        rm -rf $FFMPEG_DIR_NAME
    fi
    cp -r ../src/ffmpeg $FFMPEG_DIR_NAME
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "zlib" ]; then
    find ../src/ -type d -name "zlib-*" | xargs -i cp -r {} ./zlib
    cd ./zlib
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure --static --prefix=$INSTALL_DIR
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "bzip2" ]; then
    find ../src/ -type d -name "bzip2-*" | xargs -i cp -r {} ./bzip2
    cd ./bzip2
    patch -p1 < $PATCHES_DIR/bzip2-makefile.diff
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    make -j$NJOBS && make PREFIX=$INSTALL_DIR install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libiconv" ]; then
    find ../src/ -type d -name "libiconv-*" | xargs -i cp -r {} ./libiconv
    cd ./libiconv
    gzip -dc $PATCHES_DIR/libiconv-1.16-ja-1.patch.gz | patch -p1
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS_SMALL} -std=gnu17" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "opus" ]; then
    find ../src/ -type d -name "opus-*" | xargs -i cp -r {} ./opus
    cd ./opus
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS} -fno-tree-vectorize -fno-fast-math" \
    CPPFLAGS="${BUILD_CCFLAGS} -fno-tree-vectorize -fno-fast-math" \
    CXXFLAGS="${BUILD_CCFLAGS} -fno-tree-vectorize -fno-fast-math" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static=yes \
    --enable-shared=no \
    --disable-doc \
    --disable-extra-programs
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libogg" ]; then
    find ../src/ -type d -name "libogg-*" | xargs -i cp -r {} ./libogg
    cd ./libogg
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure --prefix=$INSTALL_DIR \
        --disable-shared
    make -j$NJOBS && make install-strip
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libvorbis" ]; then
    find ../src/ -type d -name "libvorbis-*" | xargs -i cp -r {} ./libvorbis
    cd ./libvorbis
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure --prefix=$INSTALL_DIR \
        --disable-shared
    make -j$NJOBS && make install-strip
    sed -i -e "s/^Requires.private/Requires/g" $INSTALL_DIR/lib/pkgconfig/vorbis.pc
    sed -i -e "s/^Requires.private/Requires/g" $INSTALL_DIR/lib/pkgconfig/vorbisfile.pc
    sed -i -e "s/^Requires.private/Requires/g" $INSTALL_DIR/lib/pkgconfig/vorbisenc.pc
fi


cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "dav1d" ]; then
    find ../src/ -type d -name "dav1d-*" | xargs -i cp -r {} ./dav1d
    cd ./dav1d
    CC=gcc \
    CXX=g++ \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    meson build --buildtype release
    meson configure build/ --prefix=$INSTALL_DIR -Dbuildtype=release -Ddefault_library=static -Denable_examples=false -Denable_tests=false -Dc_args="${BUILD_CCFLAGS}"
    ninja -C build install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libvpl" ]; then
    find ../src/ -type d -name "libvpl-*" | xargs -i cp -r {} ./libvpl
    cd libvpl
    script/bootstrap
    cmake -G "MSYS Makefiles" -B _build -DBUILD_SHARED_LIBS=OFF -DUSE_MSVC_STATIC_RUNTIME=ON -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
    cmake --build _build --config Release
    cmake --install _build --config Release
    # x86版の場合、$INSTALL_DIR/libに入るべきものが$INSTALL_DIR/lib/x86に入ってしまう
    # あとから強制的に移動する
    # vpl.pcのパスも移動に合わせる
    if [ $TARGET_ARCH = "x86" ]; then
        cp -r $INSTALL_DIR/lib/x86/* $INSTALL_DIR/lib/
        rm -rf $INSTALL_DIR/lib/x86
        sed -i -e 's/${pcfiledir}\/../${pcfiledir}/g' $INSTALL_DIR/lib/pkgconfig/vpl.pc
    fi
    sed -i -e 's/-lvpl/-lvpl -lstdc++/g' $INSTALL_DIR/lib/pkgconfig/vpl.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libvpx" ]; then
    find ../src/ -type d -name "libvpx-*" | xargs -i cp -r {} ./libvpx
    cd ./libvpx
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static \
     --disable-docs \
     --disable-examples \
     --disable-tools \
     --disable-unit-tests \
     --enable-vp9-highbitdepth \
     --enable-runtime-cpu-detect
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "nv-codec-headers" ]; then
    find ../src/ -type d -name "nv-codec-headers-*" | xargs -i cp -r {} ./nv-codec-headers
    cd nv-codec-headers
    make PREFIX=$INSTALL_DIR install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "l-smash" ]; then
    LSMASH_DEBUG_OPT=
    if [ $ENABLE_DEBUG = "TRUE" ]; then
        LSMASH_DEBUG_OPT="--enable-debug"
    fi
    cp -r ../src/l-smash l-smash
    cd l-smash
    ./configure \
    --prefix=$INSTALL_DIR \
    $LSMASH_DEBUG_OPT \
    --extra-cflags="${BUILD_CCFLAGS}" \
    --extra-ldflags="${BUILD_LDFLAGS}"
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ $UPDATE_FFMPEG != "FALSE" ] || [ ! -d $FFMPEG_DIR_NAME ]; then
    if [ $ENABLE_DEBUG = "TRUE" ]; then
        FFMPEG_DEBUG_OPT="--enable-debug --disable-optimizations --disable-stripping"
    else
        FFMPEG_DEBUG_OPT="--disable-debug"
    fi
    cd $FFMPEG_DIR_NAME
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure \
    --prefix=$INSTALL_DIR \
    --arch="${FFMPEG_ARCH}" \
    --target-os="mingw32" \
    --enable-version3 \
    --enable-static \
    --disable-shared \
    --disable-doc \
    $FFMPEG_DISABLE_ASM \
    $FFMPEG_DEBUG_OPT \
    --disable-outdevs \
    --disable-indevs \
    --disable-avfilter \
    --disable-muxers \
    --disable-amd3dnow \
    --disable-amd3dnowext \
    --disable-xop \
    --disable-fma4 \
    --disable-aesni \
    --disable-w32threads \
    --disable-avisynth \
    --disable-encoders \
    --disable-lzma \
    --enable-swresample \
    --enable-swscale \
    --enable-pthreads \
    --enable-bsfs \
    --disable-decoder=vorbis \
    --enable-libvorbis \
    --enable-libopus \
    --enable-libdav1d \
    --enable-libvpl \
    --enable-libvpx \
    --enable-ffnvcodec \
    --enable-nvdec \
    --enable-cuvid \
    --pkg-config-flags="--static" \
    --extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    --extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "AviSynthPlus" ]; then
    find ../src/ -type d -name "AviSynthPlus-*" | xargs -i cp -r {} ./AviSynthPlus
    cd ./AviSynthPlus
    sed -i "s/MSVC/__${MSYSTEM}__/" avs_core/filters/AviSource/avi_source.cpp
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DENABLE_PLUGINS=OFF
    cmake --build build -j$NJOBS
    cmake --install build --prefix $INSTALL_DIR
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "zimg" ]; then
    find ../src/ -type d -name "zimg-*" | xargs -i cp -r {} ./zimg
    cd ./zimg
    ./autogen.sh
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "VapourSynth" ]; then
    find ../src/ -type d -name "vapoursynth-*" | xargs -i cp -r {} ./VapourSynth
    cd ./VapourSynth
    ./autogen.sh
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
    ./configure \
    --prefix=$INSTALL_DIR \
     --disable-vsscript \
     --disable-vspipe \
     --disable-python-module
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH/L-SMASH-Works/AviSynth
CC=gcc \
CXX=g++ \
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
CFLAGS="${BUILD_CCFLAGS}" \
CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include -I${BUILD_DIR}/${TARGET_ARCH}/AviSynthPlus/avs_core/include" \
LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
meson build --buildtype release
sed -i -e 's/libstdc++.dll.a/libstdc++.a/g' build/build.ninja
sed -i -e 's/libatomic.dll.a/libatomic.a/g' build/build.ninja
ninja --verbose -C build

cd $BUILD_DIR/$TARGET_ARCH/L-SMASH-Works/VapourSynth
CC=gcc \
CXX=g++ \
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
CFLAGS="${BUILD_CCFLAGS}" \
CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include -I${BUILD_DIR}/${TARGET_ARCH}/VapourSynth/include" \
LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
meson build --buildtype release
sed -i -e 's/libstdc++.dll.a/libstdc++.a/g' build/build.ninja
sed -i -e 's/libatomic.dll.a/libatomic.a/g' build/build.ninja
ninja --verbose -C build

if [ $TARGET_ARCH = "x86" ]; then
    AVIUTL_DIR_NAME="AviUtl"
else
    AVIUTL_DIR_NAME="AviUtl2"
fi

cd $BUILD_DIR/$TARGET_ARCH/L-SMASH-Works/${AVIUTL_DIR_NAME}
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
--extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
make -j$NJOBS
