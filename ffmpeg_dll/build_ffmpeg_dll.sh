#!/bin/bash
#MSYS2用ffmpeg dllビルドスクリプト
#Visual Studioへの環境変数を通して起動する
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools autogen
#pacman -S p7zip git nasm yasm python unzip
# cmake関連
#pacman -S mingw32/mingw-w64-i686-cmake mingw64/mingw-w64-x86_64-cmake
# 通常の pacman -S cmakeで導入しないこと
#普通にpacman -S mesonとやるとうまくdav1dがビルドできないので注意
#pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson
# harfbuzzに必要
#pacman -S gtk-doc mingw64/mingw-w64-x86_64-ragel mingw32/mingw-w64-i686-ragel
#fontconfigに必要
#pacman -S gperf mingw32/mingw-w64-i686-python-lxml mingw64/mingw-w64-x86_64-python-lxml
#pacman -S mingw-w64-i686-python mingw-w64-i686-python-six
#pacman -S mingw-w64-x86_64-python mingw-w64-x86_64-python-six
#libdoviに必要
# curl -o rustup-init.exe -sSL https://win.rustup.rs/
# ./rustup-init.exe -y --default-host=x86_64-pc-windows-gnu
# rustup install stable --profile minimal
# rustup default stable
# rustup target add x86_64-pc-windows-gnu
# rustup target add x86_64-pc-windows-msvc
# rustup target add i686-pc-windows-gnu
# rustup target add i686-pc-windows-msvc
# デフォルトをgnuのほうにしておかないとlinkエラーが出る
# rustup default stable-x86_64-pc-windows-gnu
# cargo install cargo-c
# Vulkan
# pacman -S mingw-w64-i686-uasm mingw-w64-x86_64-uasm
NJOBS=$NUMBER_OF_PROCESSORS
PATCHES_DIR=$HOME/patches
Y4M_PATH=$HOME/sakura_op_cut.y4m
Y4M_10_PATH=$HOME/sakura_op_cut_10bit.y4m
YUVFILE=$HOME/sakura_op_cut.yuv
YUVFILE_10=$HOME/sakura_op_cut_10bit.yuv

BUILD_ALL="FALSE"
SSE4_2="FALSE"
UPDATE_FFMPEG="FALSE"
ENABLE_SWSCALE="FALSE"
FOR_FFMPEG4="FALSE"
FOR_AUDENC="FALSE"
ADD_TLVMMT="FALSE"
BUILD_EXE="FALSE"
ENABLE_GPL="FALSE"
ENABLE_LTO="FALSE"

# [ bitrate, swscale, exe ]
TARGET_BUILD=""

while getopts ":-:at:ur" key; do
  if [[ $key == - ]]; then
    key=${OPTARG}
    keyarg=${!OPTIND}
  fi

  case $key in
    mmttlv )
      ADD_TLVMMT="TRUE"
      ;;
    enable-gpl )
      ENABLE_GPL="TRUE"
      ;;
    enable-swscale )
      ENABLE_SWSCALE="TRUE"
      ;;
    lto )
      ENABLE_LTO="TRUE"
      ;;
    a | all )
      BUILD_ALL="TRUE"
      ;;
    u | update-ffmpeg )
      UPDATE_FFMPEG="TRUE"
      ;;
    r )
      FOR_FFMPEG4="TRUE"
      ;;
    t | target )
      TARGET_BUILD=$keyarg
      ;;
    ? | *)
      echo "help message"
      exit 0
      ;;
  esac

  while [[ -n ${!OPTIND} && ${!OPTIND} != -* ]]; do
      args+=(${!OPTIND})
      OPTIND=$((OPTIND + 1))
  done
done

BUILD_DIR=$HOME/build_ffmpeg
if [ "$FOR_FFMPEG4" = "TRUE" ]; then
    BUILD_DIR=${BUILD_DIR}4
fi

if [ $ENABLE_LTO = "TRUE" ]; then
    BUILD_DIR=${BUILD_DIR}_lto
fi


if [ "$TARGET_BUILD" = "audenc" ]; then
    FOR_AUDENC="TRUE"
    BUILD_EXE="TRUE"
elif [ "$TARGET_BUILD" = "exe" ]; then
    BUILD_EXE="TRUE"
    ENABLE_SWSCALE="TRUE"
fi

if [ $BUILD_EXE != "TRUE" ]; then
    BUILD_DIR=${BUILD_DIR}_dll
fi

echo FOR_FFMPEG4=$FOR_FFMPEG4
echo BUILD_DIR=$BUILD_DIR

mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src

if [ "$ENABLE_GPL" != "FALSE" ]; then
  if [ "$BUILD_EXE" = "FALSE" ]; then
    echo "--enable-gpl can be only used when --target exe is set."
    exit 1
  fi
fi

# [ "x86", "x64" ]
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

FFMPEG_DISABLE_ASM=""
#BUILD_CCFLAGS="-mtune=alderlake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
BUILD_CCFLAGS="-mtune=alderlake -msse2 -mfpmath=sse -fomit-frame-pointer -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
BUILD_LDFLAGS="-Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
if [ $TARGET_ARCH = "x86" ]; then
    BUILD_CCFLAGS="${BUILD_CCFLAGS} -m32 -mstackrealign"
    #  libavcodec/h264_cabac.c: In function 'ff_h264_decode_mb_cabac': libavcodec/x86/cabac.h:192:5: error: 'asm' operand has impossible 対策
    FFMPEG_DISABLE_ASM="--disable-inline-asm"
fi

if [ $ENABLE_LTO = "TRUE" ]; then
    BUILD_CCFLAGS="-flto -ffat-lto-objects ${BUILD_CCFLAGS}"
    BUILD_LDFLAGS="-flto=auto ${BUILD_LDFLAGS}"
else
    BUILD_CCFLAGS="-ffunction-sections ${BUILD_CCFLAGS}"
    BUILD_LDFLAGS="-Wl,--gc-sections ${BUILD_LDFLAGS}"
fi

PROFILE_GEN_CC="-fprofile-generate -fprofile-partial-training"
PROFILE_GEN_LD="-fprofile-generate -fprofile-partial-training"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"
PROFILE_SVTAV1="-fprofile-correction"

if [ "$FOR_FFMPEG4" = "TRUE" ]; then
    FFMPEG_DIR_NAME="ffmpeg4_dll"
else
    FFMPEG_DIR_NAME="ffmpeg_dll"
fi
FFMPEG_SSE="-msse2"
if [ $SSE4_2 = "TRUE" ]; then
    FFMPEG_DIR_NAME="${FFMPEG_DIR_NAME}_sse42"
    FFMPEG_SSE="-msse4.2 -mpopcnt"
fi

# static link用のフラグ (これらがないとundefined referenceが出る)
BUILD_CCFLAGS="${BUILD_CCFLAGS} -DLIBXML_STATIC -DFRIBIDI_LIB_STATIC"

# lameのstaticビルドに必要
BUILD_CCFLAGS="${BUILD_CCFLAGS} -DNCURSES_STATIC"

# small build用のフラグと通常用のフラグ
BUILD_CCFLAGS_SMALL="-Os -fno-unroll-loops ${BUILD_CCFLAGS}"
BUILD_CCFLAGS="-O3 ${BUILD_CCFLAGS}"

if [ $ENABLE_SWSCALE = "TRUE" ]; then
    FFMPEG_DIR_NAME="${FFMPEG_DIR_NAME}_swscale"
fi
if [ $ADD_TLVMMT = "TRUE" ]; then
    FFMPEG_DIR_NAME="${FFMPEG_DIR_NAME}_tlvmmt"
fi
if [ $FOR_AUDENC = "TRUE" ]; then
    FFMPEG_DIR_NAME="${FFMPEG_DIR_NAME}_audenc"
fi
if [ $BUILD_EXE = "TRUE" ]; then
    FFMPEG_DIR_NAME="${FFMPEG_DIR_NAME}_exe"
fi
if [ $BUILD_ALL != "FALSE" ]; then
    UPDATE_FFMPEG="TRUE"
fi

echo TARGET_ARCH=$TARGET_ARCH
echo BUILD_ALL=$BUILD_ALL
echo SSE4_2=$SSE4_2
echo UPDATE_FFMPEG=$UPDATE_FFMPEG
echo FOR_AUDENC=$FOR_AUDENC
echo ENABLE_SWSCALE=$ENABLE_SWSCALE
echo FFMPEG_DIR_NAME=$FFMPEG_DIR_NAME
echo BUILD_EXE=$BUILD_EXE
echo ENABLE_LTO=$ENABLE_LTO

#--- ソースのダウンロード ---------------------------------------
if [ "$FOR_FFMPEG4" = "TRUE" ]; then
    if [ ! -d "ffmpeg" ]; then
        wget https://ffmpeg.org/releases/ffmpeg-4.4.3.tar.xz
        tar xf ffmpeg-4.4.3.tar.xz
        mv ffmpeg-4.4.3 ffmpeg
    fi
else
    if [ ! -d "ffmpeg" ]; then
        UPDATE_FFMPEG="TRUE"
    fi
    if [ $UPDATE_FFMPEG != "FALSE" ]; then
        #if [ ! -d "ffmpeg" ] || [ ! -d "ffmpeg/.git" ]; then
        #    if [ -d "ffmpeg" ]; then
        #        rm -rf ffmpeg
        #    fi
        #    git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
        #else
        #    cd ffmpeg
        #    make uninstall && make distclean &> /dev/null
        #    cd ..
        #fi
        #cd ffmpeg
        #git fetch
        #git reset --hard
        #git checkout -b build 9d15fe77e33b757c75a4186fa049857462737713
        #cd ..
        wget https://ffmpeg.org/releases/ffmpeg-8.0.tar.xz
        tar xf ffmpeg-8.0.tar.xz
        mv ffmpeg-8.0 ffmpeg
        #wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
        #tar xf ffmpeg-snapshot.tar.bz2
    fi
fi

if [ ! -d "zlib-1.3.1" ]; then
    wget https://www.zlib.net/zlib-1.3.1.tar.xz
    tar xf zlib-1.3.1.tar.xz
fi

if [ ! -d "libpng-1.6.50" ]; then
    wget https://download.sourceforge.net/libpng/libpng-1.6.50.tar.xz
    tar xf libpng-1.6.50.tar.xz
fi

if [ ! -d "bzip2-1.0.8" ]; then
    wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
    tar xf bzip2-1.0.8.tar.gz
fi

if [ ! -d "expat-2.7.1" ]; then
    wget https://github.com/libexpat/libexpat/releases/download/R_2_7_1/expat-2.7.1.tar.xz
    tar xf expat-2.7.1.tar.xz
fi

# freetype-2.12.1はダメ
if [ ! -d "freetype-2.11.0" ]; then
    wget https://download.savannah.gnu.org/releases/freetype/freetype-2.11.0.tar.xz
    tar xf freetype-2.11.0.tar.xz
fi

if [ ! -d "libiconv-1.16" ]; then
    wget https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.16.tar.gz
    tar xf libiconv-1.16.tar.gz
fi

#2.12.6でないといろいろ面倒 -> 2.12.1もだめ, 2.13.0もだめ
if [ ! -d "fontconfig-2.12.6" ]; then
    wget https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.12.6.tar.gz
    tar xf fontconfig-2.12.6.tar.gz
fi

if [ ! -d "fribidi-1.0.16" ]; then
    wget https://github.com/fribidi/fribidi/releases/download/v1.0.16/fribidi-1.0.16.tar.xz
    tar xf fribidi-1.0.16.tar.xz
fi

#if [ ! -d "harfbuzz-3.3.1" ]; then
#    wget https://github.com/harfbuzz/harfbuzz/releases/download/3.3.1/harfbuzz-3.3.1.tar.xz
#    tar xf harfbuzz-3.3.1.tar.xz
#fi

#0.14.0でないとバイナリが異常に大きくなる
if [ ! -d "libass-0.14.0" ]; then
    wget https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.xz
    tar xf libass-0.14.0.tar.xz
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

if [ ! -d "speex-1.2.1" ]; then
    wget http://downloads.xiph.org/releases/speex/speex-1.2.1.tar.gz
    tar xf speex-1.2.1.tar.gz
fi

if [ ! -d "lame-3.100" ]; then
    wget https://jaist.dl.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz
    tar xf lame-3.100.tar.gz
fi

if [ ! -d "twolame-0.4.0" ]; then
    wget https://jaist.dl.sourceforge.net/project/twolame/twolame/0.4.0/twolame-0.4.0.tar.gz
    tar xf twolame-0.4.0.tar.gz
fi

if [ ! -d "libsndfile-1.2.2" ]; then
    wget https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz
    tar xf libsndfile-1.2.2.tar.xz
fi

if [ ! -d "soxr-0.1.3-Source" ]; then
    wget http://nchc.dl.sourceforge.net/project/soxr/soxr-0.1.3-Source.tar.xz
    tar xf soxr-0.1.3-Source.tar.xz
fi

if [ ! -d "libxml2-2.14.5" ]; then
    wget -O libxml2-2.14.5.tar.gz https://github.com/GNOME/libxml2/archive/refs/tags/v2.14.5.tar.gz
    tar xf libxml2-2.14.5.tar.gz
fi

#if [ ! -d "apache-ant-1.10.6-src.tar.xz" ]; then
#    wget https://archive.apache.org/dist/ant/source/apache-ant-1.10.6-src.tar.xz
#    tar xf apache-ant-1.10.6-src.tar.xz
#fi

if [ ! -d "libbluray-1.3.4" ]; then
    wget https://download.videolan.org/pub/videolan/libbluray/1.3.4/libbluray-1.3.4.tar.bz2
    tar xf libbluray-1.3.4.tar.bz2
fi

if [ ! -d "aribb24-master" ]; then
    wget https://github.com/nkoriyama/aribb24/archive/master.zip
    mv master.zip aribb24-master.zip
    unzip aribb24-master.zip
fi

if [ ! -d "libaribcaption-1.1.1" ]; then
    wget -O libaribcaption-1.1.1.tar.gz https://github.com/xqq/libaribcaption/archive/refs/tags/v1.1.1.tar.gz
    tar xf libaribcaption-1.1.1.tar.gz
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

# if [ ! -d "gperf-3.0.4" ]; then
    # wget http://ftp.gnu.org/gnu/gperf/gperf-3.0.4.tar.gz
    # tar xf gperf-3.0.4.tar.gz
# fi

# if [ ! -d "gmp-6.1.0" ]; then
    # wget https://gmplib.org/download/gmp/gmp-6.1.0.tar.xz --no-check-certificate
    # tar xf gmp-6.1.0.tar.xz
# fi

# if [ ! -d "nettle-2.7.1" ]; then
    # wget ftp://ftp.gnu.org/gnu/nettle/nettle-2.7.1.tar.gz
    # tar xf nettle-2.7.1.tar.gz
# fi

# if [ ! -d "gnutls-3.3.19" ]; then
    # wget ftp://ftp.gnutls.org/gcrypt/gnutls/v3.4/gnutls-3.3.19.tar.xz
    # tar xf gnutls-3.3.19.tar.xz
# fi

if [ ! -d "dav1d-1.5.1" ]; then
    wget https://code.videolan.org/videolan/dav1d/-/archive/1.5.1/dav1d-1.5.1.tar.gz
    tar xf dav1d-1.5.1.tar.gz
fi

if [ ! -d "libxxhash-0.8.3" ]; then
    wget -O libxxhash-0.8.3.tar.gz https://github.com/Cyan4973/xxHash/archive/refs/tags/v0.8.3.tar.gz
    tar xf libxxhash-0.8.3.tar.gz
    mv xxHash-0.8.3 libxxhash-0.8.3
fi

if [ ! -d "glslang-15.4.0" ]; then
    wget -O glslang-15.4.0.tar.gz https://github.com/KhronosGroup/glslang/archive/refs/tags/15.4.0.tar.gz
    tar xf glslang-15.4.0.tar.gz
fi

if [ ! -d "shaderc" ]; then
    git clone https://github.com/google/shaderc shaderc
    cd shaderc && git checkout tags/v2024.1 && python ./utils/git-sync-deps && cd ..
fi

if [ ! -d "SPIRV-Cross" ]; then
    git clone https://github.com/KhronosGroup/SPIRV-Cross.git
fi

if [ ! -d "dovi_tool-2.3.1" ]; then
    wget -O dovi_tool-2.3.1.tar.gz https://github.com/quietvoid/dovi_tool/archive/refs/tags/2.3.1.tar.gz
    tar xf dovi_tool-2.3.1.tar.gz
fi

if [ ! -d "libjpeg-turbo-3.1.1" ]; then
    wget https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.1/libjpeg-turbo-3.1.1.tar.gz
    tar xf libjpeg-turbo-3.1.1.tar.gz
fi

if [ ! -d "lcms2-2.17" ]; then
    wget https://github.com/mm2/Little-CMS/releases/download/lcms2.17/lcms2-2.17.tar.gz
    tar xf lcms2-2.17.tar.gz
fi

if [ ! -d "Vulkan-Loader-1.3.295" ]; then
    wget -O Vulkan-Loader-v1.3.295.tar.gz https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/v1.3.295.tar.gz
    tar xf Vulkan-Loader-v1.3.295.tar.gz
fi

if [ ! -d "zimg-3.0.6" ]; then
    wget -O zimg-3.0.6.tar.gz https://github.com/sekrit-twc/zimg/archive/refs/tags/release-3.0.6.tar.gz
    tar xf zimg-3.0.6.tar.gz
    mv zimg-release-3.0.6 zimg-3.0.6
fi

# 依存関係は以下の通り
# [ libjpeg -> lcms2 ], shaderc, SPIRV-Cross, dovi_tool, libxxhash, vulkan-loader -> libplacebo
# shadercがあればglslangは不要
if [ ! -d "libplacebo" ]; then
    git clone --recursive https://code.videolan.org/videolan/libplacebo
    cd libplacebo && git checkout tags/v7.351.0 && cd ..
fi

if [ ! -d "vvenc-1.13.1" ]; then
    wget -O vvenc-v1.13.1.tar.gz https://github.com/fraunhoferhhi/vvenc/archive/refs/tags/v1.13.1.tar.gz
    tar xf vvenc-v1.13.1.tar.gz
fi

if [ ! -d "svt-av1" ]; then
    wget https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v3.1.0/SVT-AV1-v3.1.0.tar.gz
    tar xf SVT-AV1-v3.1.0.tar.gz
    mv SVT-AV1-v3.1.0 svt-av1
fi

if [ $ENABLE_GPL = "TRUE" ]; then
    if [ ! -d "xvidcore" ]; then
        wget https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz
        tar xf xvidcore-1.3.7.tar.gz
    fi
    if [ ! -d "x264" ]; then
        git clone https://code.videolan.org/videolan/x264.git
    fi
    if [ ! -d "x265" ]; then
        git clone https://bitbucket.org/multicoreware/x265_git.git x265
    fi
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
if [ $UPDATE_FFMPEG != "FALSE" ] && [ -d ffmpeg_test ]; then
    rm -rf ffmpeg_test
fi
if [ ! -d ffmpeg_test ]; then
    cp -r ../src/ffmpeg ffmpeg_test
fi

if [ -d $FFMPEG_DIR_NAME ]; then
    rm -rf $FFMPEG_DIR_NAME
fi
cp -r ../src/ffmpeg $FFMPEG_DIR_NAME

if [ $ADD_TLVMMT = "TRUE" ]; then
    cd $FFMPEG_DIR_NAME
    echo "Patch ffmpeg_tlvmmt.diff..."
    patch -p1 < $PATCHES_DIR/ffmpeg_tlvmmt.diff
    echo "Patch ffmpeg_tlvmmt_asset_group_desc.diff..."
    patch -p1 < $PATCHES_DIR/ffmpeg_tlvmmt_asset_group_desc.diff
    read -p "Check patch and hit enter: "
fi
  
  #$BUILD_DIR/src/soxr* $BUILD_DIR/src/nettle* $BUILD_DIR/src/gnutls*


# --- ビルド開始 対象のフォルダがなければビルドを行う -----------
# if [ ! -d "zlib" ]; then
    # cd $BUILD_DIR/$TARGET_ARCH
    # find ../src/ -type d -name "zlib-*" | xargs -i cp -r {} ./zlib
    # cd $BUILD_DIR/$TARGET_ARCH/zlib
    # CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # make -f win32/Makefile.gcc
    # rm -f $INSTALL_DIR/lib/libz.a
    # rm -f $INSTALL_DIR/include/zlib.h $INSTALL_DIR/include/zconf.h
    # cp libz.a $INSTALL_DIR/lib/
    # cp zlib.h zconf.h $INSTALL_DIR/include/
# fi

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
if [ ! -d "libpng" ]; then
    find ../src/ -type d -name "libpng-*" | xargs -i cp -r {} ./libpng
    cd ./libpng
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared
    make -j$NJOBS && make install
fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "gperf" ]; then
    # find ../src/ -type d -name "gperf-*" | xargs -i cp -r {} ./gperf
    #libiconvにgperf.exeが必要
    #3.0.4必須 (3.1だと、fontconfigでエラーが出る場合がある)
    # cd ./gperf
    # CFLAGS="${BUILD_CCFLAGS}" \
    # CPPFLAGS="${BUILD_CCFLAGS}" \
    # CXXFLAGS="${BUILD_CCFLAGS}" \
    # ./configure \
    # --prefix=$INSTALL_DIR \
    # --enable-static \
    # --disable-shared
    # make -j$NJOBS
    # texがないとのエラーが出るが無視する
    # make install
# fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "expat" ]; then
    find ../src/ -type d -name "expat-*" | xargs -i cp -r {} ./expat
    cd ./expat
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared \
    --without-docbook \
    --without-xmlwf \
    --without-examples \
    --without-tests \
    --without-getrandom 
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "freetype" ]; then
    find ../src/ -type d -name "freetype-*" | xargs -i cp -r {} ./freetype
    #msys側のzlib(zlib.h, zconf.h, libz.a, libz.pcを消さないとうまくいかない)
    #あるいはconfigure後に、build/unix/unix-cc.mk内の
    #CFLAGSから-IC:/.../MSYS/includeとLDFLAGSの-LC:/.../MSYS/libを消す
    cd ./freetype
    ZLIB_CFLAGS=" -I${INSTALL_DIR}/include" \
    ZLIB_LIBS="-L${INSTALL_DIR}/lib -lz" \
    BZIP2_CFLAGS=" -I${INSTALL_DIR}/include" \
    BZIP2_LIBS="-L${INSTALL_DIR}/lib -lbz2" \
    LIBPNG_CFLAGS=" -I${INSTALL_DIR}/include" \
    LIBPNG_LIBS="-L${INSTALL_DIR}/lib -lpng -lz" \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --disable-shared \
    --with-png=yes \
    --with-zlib=yes \
    --with-bzip2=yes \
    --with-brotli=no
    make -j$NJOBS && make install
    sed -i -e "s/ -lfreetype$/ -lfreetype -liconv -lpng -lbz2 -lz/g" $INSTALL_DIR/lib/pkgconfig/freetype2.pc
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
if [ ! -d "fontconfig" ]; then
    find ../src/ -type d -name "fontconfig-*" | xargs -i cp -r {} ./fontconfig
    cd ./fontconfig
    autoreconf -fvi
    FREETYPE_CFLAGS=-I$INSTALL_DIR/include/freetype2 \
    FREETYPE_LIBS="-L$INSTALL_DIR/lib -lfreetype" \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CXXFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --disable-shared \
    --enable-static \
    --enable-iconv --with-libiconv-includes=$INSTALL_DIR/include \
    --disable-docs \
    --disable-libxml2
    make -j$NJOBS && make install
    #pkgconfig情報を書き換える
    sed -i -e "s/ -lfontconfig$/ -lfontconfig -lexpat -lpng -lz/g" $INSTALL_DIR/lib/pkgconfig/fontconfig.pc
    sed -i -e "s/ -lfreetype$/ -lfreetype -liconv -lpng -lz/g" $INSTALL_DIR/lib/pkgconfig/fontconfig.pc
    sed -i -e "s/^Requires:[ \f\n\r\t]\+freetype2/Requires: freetype2 libpng/g" $INSTALL_DIR/lib/pkgconfig/fontconfig.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "fribidi" ]; then
    find ../src/ -type d -name "fribidi-*" | xargs -i cp -r {} ./fribidi
    cd ./fribidi
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --enable-shared=no
    make -j$NJOBS && make install
fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "harfbuzz" ]; then
    # find ../src/ -type d -name "harfbuzz-*" | xargs -i cp -r {} ./harfbuzz
    # cd ./harfbuzz
    # autoreconf -fvi
    # PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    # CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # ./configure \
    # --prefix=$INSTALL_DIR \
    # --enable-static \
    # --enable-shared=no \
    # --enable-gtk-doc-html=no
    # make -j$NJOBS && make install
# fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libass" ]; then
    find ../src/ -type d -name "libass-*" | xargs -i cp -r {} ./libass
    if [ -d "libass_dll" ]; then
        rm -rf libass_dll
    fi
    cp -r ./libass ./libass_dll
    cd ./libass
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS_SMALL} -I${INSTALL_DIR}/include" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL} -L${INSTALL_DIR}/lib -liconv" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static \
    --enable-shared=no
    make -j$NJOBS && make install

    cd $BUILD_DIR/$TARGET_ARCH/libass_dll
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CC="gcc -static-libgcc -static-libstdc++" \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    LDFLAGS="-L${INSTALL_DIR}/lib -static-libgcc -static-libstdc++ -Wl,-Bstatic -Wl,-lm,-liconv,-lfreetype,-lfribidi,-lfontconfig,-lexpat,-lfreetype,-lpng,-lbz2,-lz" \
    ./configure \
    --prefix=$INSTALL_DIR \
    --enable-static=no \
    --enable-shared=yes
    #実行したコマンドを出力するように
    sed -i -e 's/AM_DEFAULT_VERBOSITY = 0/AM_DEFAULT_VERBOSITY = 1/g' libass/Makefile
    make -j$NJOBS
    cd libass
    # ../libtool --tag=CC   --mode=link gcc -std=gnu99 \
    # -D_GNU_SOURCE \
    # ${BUILD_CCFLAGS_SMALL} \
    # -I${INSTALL_DIR}/include/freetype2 \
    # -I${INSTALL_DIR}/include/fribidi \
    # -I${INSTALL_DIR}/include \
    # -I${INSTALL_DIR}/include/freetype2 \
    # -no-undefined -version-info 8:0:3 -export-symbols ./libass.sym  -o libass.la -rpath ${INSTALL_DIR}/lib \
    # `find ./ -name "*.lo" | tr '\n' ' '` \
    # -L${INSTALL_DIR}/lib \
    # -static -static-libgcc -static-libstdc++ \
    # -Wl,-lm,-liconv,-lfreetype,-lfribidi,-lfontconfig,-lexpat,-lfreetype,-lpng,-lbz2,-lz \
    # -Wl,--output-def,libass.def -Wl,-s -Wl,-gc-sections
    # sed -i -e "s/ @[^ ]*//" libass.def

    LIBASS_DEF_FILENAME=`find ./.libs/libass-*.dll`.def
    LIBASS_DEF_FILENAME=${LIBASS_DEF_FILENAME/.dll.def/.def}
    cp -f `find ./.libs/libass-*.dll`.def ${LIBASS_DEF_FILENAME}
    cp -f ${LIBASS_DEF_FILENAME} .
    LIBASS_DEF_FILENAME=`basename $LIBASS_DEF_FILENAME`
    sed -i -e "s/ @[^ ]*//" ${LIBASS_DEF_FILENAME}
    LIBASS_LIB_FILENAME=$(basename $LIBASS_DEF_FILENAME .def).lib
    lib.exe -machine:$TARGET_ARCH -def:$LIBASS_DEF_FILENAME -out:$LIBASS_LIB_FILENAME
    cp `find ./.libs/libass-*.dll` .
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
if [ ! -d "speex" ]; then
    find ../src/ -type d -name "speex-*" | xargs -i cp -r {} ./speex
    cd ./speex
    autoreconf -fvi
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure --prefix=$INSTALL_DIR \
        --disable-shared
    make -j$NJOBS
    make install-strip
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "lame" ]; then
    find ../src/ -type d -name "lame-*" | xargs -i cp -r {} ./lame
    cd ./lame
    patch -p1 < $PATCHES_DIR/lame-3.100-parse_c.diff
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static \
     --disable-decoder
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libsndfile" ]; then
    find ../src/ -type d -name "libsndfile-*" | xargs -i cp -r {} ./libsndfile
    cd ./libsndfile
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "twolame" ]; then
    find ../src/ -type d -name "twolame-*" | xargs -i cp -r {} ./twolame
    cd ./twolame
    patch -p1 < $PATCHES_DIR/twolame-0.4.0-mingw.diff
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "soxr" ]; then
    find ../src/ -type d -name "soxr-*" | xargs -i cp -r {} ./soxr
    cd ./soxr
    which cmake
    cmake --version
    cmake -G "MSYS Makefiles" \
    -D BUILD_SHARED_LIBS:BOOL=FALSE \
    -D CMAKE_C_FLAGS_RELEASE:STRING="${BUILD_CCFLAGS}" \
    -D CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING="${BUILD_LDFLAGS}" \
    -D WITH_OPENMP:BOOL=NO \
    -D BUILD_TESTS:BOOL=NO \
    -D CMAKE_INSTALL_PREFIX=$INSTALL_DIR \
    -D CMAKE_POLICY_VERSION_MINIMUM=3.5 \
    .
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libxml2" ]; then
    find ../src/ -type d -name "libxml2-*" | xargs -i cp -r {} ./libxml2
    cd ./libxml2
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static \
     --without-python
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libbluray" ]; then
    find ../src/ -type d -name "libbluray-*" | xargs -i cp -r {} ./libbluray
    cd ./libbluray
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static \
     --disable-bdjava-jar \
     --disable-doxygen-doc \
     --disable-examples
    make install -j$NJOBS
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "aribb24" ]; then
    find ../src/ -type d -name "aribb24-*" | xargs -i cp -r {} ./aribb24
    cd ./aribb24
    autoreconf -fvi
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
     ./configure \
     --prefix=$INSTALL_DIR \
     --disable-shared \
     --enable-static
    make install -j$NJOBS
    sed -i -e 's/Version: 1.0.3/Version: 1.0.4/g' ${INSTALL_DIR}/lib/pkgconfig/aribb24.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libaribcaption" ]; then
    find ../src/ -type d -name "libaribcaption-*" | xargs -i cp -r {} ./libaribcaption
    cd ./libaribcaption
    mkdir build && cd build
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    cmake .. -G "MSYS Makefiles" -DCMAKE_BUILD_TYPE=Release -DARIBCC_USE_FONTCONFIG=ON -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
    cmake --build . -j$NJOBS
    cmake --install .
    #sed -i -e 's/-lC:\//-l\/c\//g' ${INSTALL_DIR}/lib/pkgconfig/libaribcaption.pc
    #下記のように変更しないと適切にリンクできない
    # -lC:/mingw64/mingw64/lib/libstdc+++.a -> -lstdc++
    sed -i -e "s/-l[A-Z]:\/.\+\/lib\/libstdc++\.a/-lstdc++/g" ${INSTALL_DIR}/lib/pkgconfig/libaribcaption.pc
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
    cmake -G "MSYS Makefiles" -B _build -DBUILD_SHARED_LIBS=OFF -DUSE_MSVC_STATIC_RUNTIME=ON -DCMAKE_BUILD_TYPE=Release -DINSTALL_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
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
if [ ! -d "libxxhash" ]; then
    find ../src/ -type d -name "libxxhash-*" | xargs -i cp -r {} ./libxxhash
    cd ./libxxhash
    CC=gcc \
    CXX=g++ \
    CFLAGS="${BUILD_CCFLAGS} -DXXH_STATIC_LINKING_ONLY" \
    CPPFLAGS="${BUILD_CCFLAGS} -DXXH_STATIC_LINKING_ONLY" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    PREFIX=$INSTALL_DIR \
    DISPATCH=1 \
    make 
    make install
fi

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

if [ $BUILD_EXE = "TRUE" ]; then
  cd $BUILD_DIR/$TARGET_ARCH
  if [ ! -d "glslang" ]; then
      find ../src/ -type d -name "glslang-*" | xargs -i cp -r {} ./glslang
      cd ./glslang
      ./update_glslang_sources.py
      mkdir -p build && cd build
      PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
      CFLAGS="${BUILD_CCFLAGS}" \
      CPPFLAGS="${BUILD_CCFLAGS}" \
      LDFLAGS="${BUILD_LDFLAGS}" \
      cmake ../ -G "MSYS Makefiles" -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DINSTALL_GTEST=OFF -DGLSLANG_TESTS=OFF
      make -j$NJOBS && make install
  fi
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libjpeg-turbo" ]; then
    find ../src/ -type d -name "libjpeg-*" | xargs -i cp -r {} ./libjpeg-turbo
    cd ./libjpeg-turbo
    mkdir build && cd build
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    cmake -G "MSYS Makefiles" -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=OFF -DENABLE_STATIC=ON ..
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "lcms2" ]; then
    find ../src/ -type d -name "lcms2*" | xargs -i cp -r {} ./lcms2
    cd ./lcms2
    CC=gcc \
    CXX=g++ \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
    meson build --buildtype release --prefix=$INSTALL_DIR -Ddefault_library=static -Dprefer_static=true -Dstrip=true -Dthreaded=false -Dfastfloat=false
    ninja -C build install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "shaderc" ]; then
    find ../src/ -type d -name "shaderc*" | xargs -i cp -r {} ./shaderc
    cd ./shaderc
    patch -p1 < $HOME/patches/shaderc_add_shaderc_util.diff
    mkdir build && cd build
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
    cmake -GNinja -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DBUILD_SHARED_LIBS=OFF -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DINSTALL_GTEST=OFF ..
    ninja
    ninja install
    mv -f ${INSTALL_DIR}/lib/pkgconfig/shaderc_static.pc ${INSTALL_DIR}/lib/pkgconfig/shaderc.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "SPIRV-Cross" ]; then
    find ../src/ -type d -name "SPIRV-Cross*" | xargs -i cp -r {} ./SPIRV-Cross
    cd ./SPIRV-Cross
    mkdir build && cd build
    CC=gcc \
    CXX=g++ \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    cmake -G "MSYS Makefiles" -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_SHARED=OFF -DSPIRV_CROSS_CLI=OFF ..
    make -j$NJOBS && make install
    sed -i -e 's/-lspirv-cross-c/-lspirv-cross-c -lspirv-cross-msl -lspirv-cross-hlsl -lspirv-cross-cpp -lspirv-cross-glsl -lspirv-cross-util -lspirv-cross-core -lspirv-cross-reflect -lstdc++/g' ${INSTALL_DIR}/lib/pkgconfig/spirv-cross-c.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "Vulkan-Loader" ]; then
    find ../src/ -type d -name "Vulkan-Loader*" | xargs -i cp -r {} ./Vulkan-Loader
    cd ./Vulkan-Loader
    patch -p1 < $HOME/patches/vulkan_loader_static.diff
    mkdir build && cd build
    python ../scripts/update_deps.py --no-build
    cd Vulkan-Headers
    cmake -G "MSYS Makefiles" -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DVULKAN_HEADERS_ENABLE_MODULE=OFF
    make -j$NJOBS && make install
    cd ..
    CC=gcc \
    CXX=g++ \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include -DUNIX=OFF -DSTRSAFE_NO_DEPRECATE" \
    CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include -DUNIX=OFF -DSTRSAFE_NO_DEPRECATE" \
    LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
    cmake -G "MSYS Makefiles" -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DUNIX=OFF -DVULKAN_HEADERS_INSTALL_DIR=${INSTALL_DIR} ..
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libplacebo" ]; then
    find ../src/ -type d -name "libplacebo*" | xargs -i cp -r {} ./libplacebo
    cd ./libplacebo
    patch -p1 < $HOME/patches/libplacebo_use_shaderc_combined.diff
    patch -p1 < $HOME/patches/libplacebo_d3d11_build.diff
    CC=gcc \
    CXX=g++ \
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
    LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
    meson build --buildtype release --prefix=$INSTALL_DIR -Dd3d11=enabled -Ddefault_library=static -Dprefer_static=true -Dstrip=true
    ninja -C build install
    #下記のように変更しないと適切にリンクできない
    # C:/mingw64/mingw64/lib/libshlwapi.a -> -llibshlwapi
    sed -i -e "s/[A-Z]:\/.\+\/lib\/libshlwapi\.a/-lshlwapi/g" ${INSTALL_DIR}/lib/pkgconfig/libplacebo.pc
    sed -i -e "s/[A-Z]:\/.\+\/lib\/libversion\.a/-lversion/g" ${INSTALL_DIR}/lib/pkgconfig/libplacebo.pc
fi

if [ $BUILD_EXE != "TRUE" ]; then
    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "libplacebo_dll" ]; then
        find ../src/ -type d -name "libplacebo*" | xargs -i cp -r {} ./libplacebo_dll
        cd ./libplacebo_dll
        patch -p1 < $HOME/patches/libplacebo_use_shaderc_combined.diff
        patch -p1 < $HOME/patches/libplacebo_d3d11_build.diff
        CC=gcc \
        CXX=g++ \
        PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
        CFLAGS="${BUILD_CCFLAGS}" \
        CPPFLAGS="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include" \
        LDFLAGS="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib" \
        meson build --buildtype release --prefix=$INSTALL_DIR -Dd3d11=enabled -Ddefault_library=shared -Dprefer_static=false -Dstrip=true
        sed -i 's/libstdc++.dll.a/libstdc++.a/g' build/build.ninja
        ninja -C build

        #dllからlib,defファイルを作成
        cd build/src
        LIBPLACEBO_DLL_FILENAME=$(basename `find ./libplacebo-*.dll`)
        LIBPLACEBO_DLL_FILENAME_WITHOUT_EXT=${LIBPLACEBO_DLL_FILENAME/.dll/}
        LIBPLACEBO_DEF_FILENAME=${LIBPLACEBO_DLL_FILENAME}.def
        LIBPLACEBO_DEF_FILENAME=${LIBPLACEBO_DEF_FILENAME/.dll.def/.def}
        echo ${LIBPLACEBO_DLL_FILENAME_WITHOUT_EXT}
        echo "dumpbin.exe /exports ${LIBPLACEBO_DLL_FILENAME} > ${LIBPLACEBO_DEF_FILENAME}.tmp" > dumpbin.bat
        eval "./dumpbin.bat"
        echo "LIBRARY ${LIBPLACEBO_DLL_FILENAME_WITHOUT_EXT}" > ${LIBPLACEBO_DEF_FILENAME}
        echo "EXPORTS" >> ${LIBPLACEBO_DEF_FILENAME}
        sed -n '/ordinal hint/,/Summary/p' ${LIBPLACEBO_DEF_FILENAME}.tmp | sed '/ordinal hint\|^$\|Summary/d' | awk '{print " "$4}' >> ${LIBPLACEBO_DEF_FILENAME}
        LIBPLACEBO_LIB_FILENAME=$(basename $LIBPLACEBO_DEF_FILENAME .def).lib
        lib.exe -machine:$TARGET_ARCH -def:$LIBPLACEBO_DEF_FILENAME -out:$LIBPLACEBO_LIB_FILENAME
        #cp `find ./.libs/libass-*.dll` .
    fi
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "zimg" ]; then
    find ../src/ -type d -name "zimg*" | xargs -i cp -r {} ./zimg
    cd zimg
    ./autogen.sh
    
    CFLAGS="${BUILD_CCFLAGS}" \
    CXXFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
        ./configure \
        --prefix=$INSTALL_DIR \
        --disable-shared \
        --enable-static
    make -j$NJOBS && make install
fi

if [ $ENABLE_GPL = "TRUE" ]; then
    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "x264" ]; then
        find ../src/ -type d -name "x264*" | xargs -i cp -r {} ./x264
        cd x264
        X264_ENABLE_LTO=
        if [ $ENABLE_LTO = "TRUE" ]; then
            X264_ENABLE_LTO=--enable-lto
        fi
        patch < $HOME/patches/x264_makefile.diff
        PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
        ./configure \
         --prefix=$INSTALL_DIR \
         --enable-strip \
         --disable-ffms \
         --disable-gpac \
         --disable-lavf \
         --enable-static \
         --disable-shared \
         $X264_ENABLE_LTO \
         --bit-depth=all \
         --extra-cflags="${BUILD_CCFLAGS}" \
         --extra-ldflags="${BUILD_LDFLAGS}"
        make fprofiled VIDS="${Y4M_PATH}" -j$NJOBS && make install
    fi

    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "x265" ]; then
        find ../src/ -type d -name "x265*" | xargs -i cp -r {} ./x265
        cd x265
        patch -p 1 < $HOME/patches/x265_version.diff
        patch -p 1 < $HOME/patches/x265_zone_param.diff
        patch -p 0 < $HOME/patches/x265_json11.diff
        mkdir build/msys2 && cd build/msys2
        mkdir 8bit
        mkdir 12bit && cd 12bit
        cmake -G "MSYS Makefiles" ../../../source \
            -DHIGH_BIT_DEPTH=ON \
            -DEXPORT_C_API=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_ALPHA=ON \
            -DENABLE_MULTIVIEW=ON \
            -DENABLE_SCC_EXT=ON \
            -DENABLE_HDR10_PLUS=OFF \
            -DENABLE_CLI=OFF \
            -DMAIN12=ON \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS}"
        make -j${NJOBS} &
        
        cd ../
        mkdir 10bit && cd 10bit
        cmake -G "MSYS Makefiles" ../../../source \
            -DHIGH_BIT_DEPTH=ON \
            -DEXPORT_C_API=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_ALPHA=ON \
            -DENABLE_MULTIVIEW=ON \
            -DENABLE_SCC_EXT=ON \
            -DENABLE_HDR10_PLUS=ON \
            -DENABLE_CLI=OFF \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"
        make -j${NJOBS} &

        cd ../8bit
        wait
        cp ../10bit/libx265.a libx265_main10.a
        cp ../12bit/libx265.a libx265_main12.a
        X265_EXTRA_LIB="x265_main10;x265_main12"
        cmake -G "MSYS Makefiles" ../../../source \
            -DEXTRA_LIB="${X265_EXTRA_LIB}" \
            -DEXTRA_LINK_FLAGS=-L. \
            -DLINKED_10BIT=ON \
            -DLINKED_12BIT=ON \
            -DENABLE_SHARED=OFF \
            -DENABLE_ALPHA=ON \
            -DENABLE_MULTIVIEW=ON \
            -DENABLE_SCC_EXT=ON \
            -DENABLE_HDR10_PLUS=OFF \
            -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"
        make -j${NJOBS}

        #profileのための実行はシングルスレッドで行う
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --preset faster
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --preset fast
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}"
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --preset slow
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --preset slower
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 10 --preset faster
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 10 --preset fast
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 10
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 10 --preset slow
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 10 --preset slower
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 12 --preset faster
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 12 --preset fast
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 12
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 12 --preset slow
        ./x265 --pools none --frame-threads 1 --lookahead-slices 0 --y4m -o /dev/null --input "${Y4M_PATH}" --output-depth 12 --preset slower
        
        cd ../12bit
        cmake -G "MSYS Makefiles" ../../../source \
            -DHIGH_BIT_DEPTH=ON \
            -DEXPORT_C_API=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_ALPHA=ON \
            -DENABLE_MULTIVIEW=ON \
            -DENABLE_SCC_EXT=ON \
            -DENABLE_HDR10_PLUS=OFF \
            -DSTATIC_LINK_CRT=ON \
            -DENABLE_CLI=OFF \
            -DMAIN12=ON \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS}"
        make -j${NJOBS} &
        
        cd ../10bit
        cmake -G "MSYS Makefiles" ../../../source \
            -DHIGH_BIT_DEPTH=ON \
            -DEXPORT_C_API=OFF \
            -DENABLE_SHARED=OFF \
            -DENABLE_ALPHA=ON \
            -DENABLE_MULTIVIEW=ON \
            -DENABLE_SCC_EXT=ON \
            -DENABLE_HDR10_PLUS=ON \
            -DSTATIC_LINK_CRT=ON \
            -DENABLE_CLI=OFF \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"
        make -j${NJOBS} &

        cd ../8bit
        wait
        cp ../10bit/libx265.a libx265_main10.a
        cp ../12bit/libx265.a libx265_main12.a
        X265_EXTRA_LIB="x265_main10;x265_main12"
        cmake -G "MSYS Makefiles" ../../../source \
            -DEXTRA_LIB="${X265_EXTRA_LIB}" \
            -DEXTRA_LINK_FLAGS=-L. \
            -DLINKED_10BIT=ON \
            -DLINKED_12BIT=ON \
            -DSTATIC_LINK_CRT=ON \
            -DENABLE_SHARED=OFF \
            -DENABLE_ALPHA=ON \
            -DENABLE_MULTIVIEW=ON \
            -DENABLE_SCC_EXT=ON \
            -DENABLE_HDR10_PLUS=OFF \
            -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD}"
        make -j${NJOBS}

        mv libx265.a libx265_main.a
        echo -n -e "create libx265.a\naddlib libx265_main.a\naddlib libx265_main10.a\naddlib libx265_main12.a\nsave\nend" | ar -M
        make install
        # static linkがうまくいくように書き換え
        sed -i -e 's/^Libs.private:.*/Libs.private: -lstdc++/g' $INSTALL_DIR/lib/pkgconfig/x265.pc
    fi
    
    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "xvidcore" ]; then
        find ../src/ -type d -name "xvidcore*" | xargs -i cp -r {} ./xvidcore
        cd xvidcore/build/generic
        ./configure --help
        ./bootstrap.sh
        CFLAGS="${BUILD_CCFLAGS} -std=gnu17" \
        CPPFLAGS=${BUILD_CCFLAGS} \
        LDFLAGS=${BUILD_LDFLAGS} \
        ./configure --prefix=$INSTALL_DIR
        make -j${NUMBER_OF_PROCESSORS}
        cp ../../src/xvid.h $INSTALL_DIR/include/
        cp '=build/xvidcore.a' $INSTALL_DIR/lib/libxvidcore.a
    fi
fi

if [ $TARGET_ARCH != "x86" ]; then
    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "vvenc" ]; then
        find ../src/ -type d -name "vvenc*" | xargs -i cp -r {} ./vvenc
        cd vvenc
        mkdir build && cd build
        CC=gcc \
        CXX=g++ \
        PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
        CFLAGS="${BUILD_CCFLAGS}" \
        CPPFLAGS="${BUILD_CCFLAGS}" \
        LDFLAGS="${BUILD_LDFLAGS}" \
        cmake -G "MSYS Makefiles" -B build/release-static -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=Release -DVVENC_INSTALL_FULLFEATURE_APP=ON -DVVENC_ENABLE_THIRDPARTY_JSON=OFF ..
        cmake --build build/release-static -j$NJOBS && cmake --build build/release-static --target install
        # static linkがうまくいくように書き換え
        sed -i -e 's/-lvvenc/-lvvenc -lstdc++/g' $INSTALL_DIR/lib/pkgconfig/libvvenc.pc
    fi

    cd $BUILD_DIR/$TARGET_ARCH
    if [ ! -d "svt-av1" ]; then
        find ../src/ -type d -name "svt-av1*" | xargs -i cp -r {} ./svt-av1
        cd svt-av1
        mkdir build/msys2 && cd build/msys2
        SVTAV1_ENABLE_LTO=OFF
        if [ $ENABLE_LTO = "TRUE" ]; then
            SVTAV1_ENABLE_LTO=ON
        fi
        cmake -G "MSYS Makefiles" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_TESTING=OFF \
            -DNATIVE=OFF \
            -DSVT_AV1_LTO=$SVTAV1_ENABLE_LTO \
            -DENABLE_NASM=ON \
            -DENABLE_AVX512=ON \
            -DCMAKE_ASM_NASM_COMPILER=nasm \
            -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC} ${PROFILE_SVTAV1}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_GEN_CC} ${PROFILE_SVTAV1}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_GEN_LD} ${PROFILE_SVTAV1}" \
            ../..
        make -j${NUMBER_OF_PROCESSORS}

        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 4 -n 30 --asm avx512
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 8 -n 30 --asm avx512
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 4 -n 30 --asm avx2
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE}    --preset 8 -n 30 --asm avx2
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 4 -n 30 --input-depth 10 --asm avx512
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 8 -n 30 --input-depth 10 --asm avx512
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 4 -n 30 --input-depth 10 --asm avx2
        ../../Bin/Release/SvtAv1EncApp.exe -w 1280 -h 720 --crf 30 --scd 1 --fps-num 30 --fps-denom 1 -b /dev/null -i ${YUVFILE_10} --preset 8 -n 30 --input-depth 10 --asm avx2

        cmake -G "MSYS Makefiles" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS=OFF \
            -DBUILD_TESTING=OFF \
            -DNATIVE=OFF \
            -DSVT_AV1_LTO=$SVTAV1_ENABLE_LTO \
            -DENABLE_NASM=ON \
            -DENABLE_AVX512=ON \
            -DCMAKE_ASM_NASM_COMPILER=nasm \
            -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
            -DCMAKE_C_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC} ${PROFILE_SVTAV1}" \
            -DCMAKE_CXX_FLAGS="${BUILD_CCFLAGS} ${PROFILE_USE_CC} ${PROFILE_SVTAV1}" \
            -DCMAKE_EXE_LINKER_FLAGS="${BUILD_LDFLAGS} ${PROFILE_USE_LD} ${PROFILE_SVTAV1}" \
            ../..
        make -j${NUMBER_OF_PROCESSORS} && make install
    fi
fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "gmp" ]; then
    # find ../src/ -type d -name "gmp-*" | xargs -i cp -r {} ./gmp
    # cd ./gmp
    # PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    # CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # LDFLAGS="${BUILD_LDFLAGS}" \
     # ./configure \
     # --prefix=$INSTALL_DIR \
     # --disable-shared \
     # --enable-static
     # make install -j$NJOBS
 # fi

# cd $BUILD_DIR/$TARGET_ARCH
# if [ ! -d "nettle" ]; then
    # find ../src/ -type d -name "nettle-*" | xargs -i cp -r {} ./nettle
    # cd ./nettle
    # PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    # CFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
    # LDFLAGS="${BUILD_LDFLAGS}" \
     # ./configure \
     # --prefix=$INSTALL_DIR \
     # --disable-shared \
     # --enable-static --disable-openssl
    # make install -j$NJOBS
# fi

# cd $BUILD_DIR/$TARGET_ARCH/gnutls
# PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
# CFLAGS="${BUILD_CCFLAGS_SMALL}" \
# CPPFLAGS="${BUILD_CCFLAGS_SMALL}" \
# LDFLAGS="${BUILD_LDFLAGS}" \
# ./configure \
# --prefix=$INSTALL_DIR \
# --disable-shared --disable-cxx \
# --disable-openssl-compatibility \
# --disable-doc --disable-gtk-doc-html \
# --with-included-libtasn1 --without-p11-kit
# sed -i.orig -e "/Libs.private:/s/$/ -lcrypt32/" lib/gnutls.pc
# make install -j$NJOBS

if [ $ENABLE_SWSCALE = "TRUE" ]; then
    SWSCALE_ARG="--enable-swscale"
else
    SWSCALE_ARG="--disable-swscale"
fi

if [ $FOR_FFMPEG4 = "TRUE" ]; then
    PKG_CONFIG_FLAGS=""
    FFMPEG5_CUDA_DISABLE_FLAGS=""
else
    PKG_CONFIG_FLAGS="--pkg-config-flags=\"--static\""
    FFMPEG5_CUDA_DISABLE_FLAGS=" --disable-cuda-nvcc --disable-cuda-llvm"
fi

if [ $TARGET_ARCH != "x86" ]; then
    ENCODER_LIBS="--enable-libvvenc --enable-libsvtav1"
else
    ENCODER_LIBS=""
fi

if [ $ENABLE_GPL = "TRUE" ]; then
  GPL_LIBS="--enable-gpl --enable-libx264 --enable-libx265 --enable-libxvid"
else
  GPL_LIBS=""
fi

cd $BUILD_DIR/$TARGET_ARCH/$FFMPEG_DIR_NAME
if [ $FOR_AUDENC = "TRUE" ]; then
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
--prefix=${BUILD_DIR}/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH \
$PKG_CONFIG_FLAGS \
--arch="${FFMPEG_ARCH}" \
--target-os="mingw32" \
--enable-version3 \
--disable-doc \
$SWSCALE_ARG \
$FFMPEG_DISABLE_ASM \
$GPL_LIBS \
--disable-avdevice \
--disable-hwaccels \
--disable-devices \
--disable-debug \
--disable-shared \
--disable-amd3dnow \
--disable-amd3dnowext \
--disable-dxva2 \
--disable-d3d11va \
$FFMPEG5_CUDA_DISABLE_FLAGS \
--disable-xop \
--disable-fma4 \
--disable-network \
--disable-bsfs \
--enable-swresample \
--disable-protocols \
--enable-protocol="file,pipe,fd" \
--disable-decoders \
--enable-decoder="pcm*,adpcm*" \
--disable-demuxers \
--enable-demuxer="wav" \
--disable-encoders \
--enable-encoder="aac,ac3*,alac,adpcm*,eac3,flac,libmp3lame,libopus,libspeex,libtwolame,libmp3lame,libvorbis,mp2*,opus,pcm*,truehd,vorbis,wma*" \
--enable-libvorbis \
--enable-libspeex \
--enable-libmp3lame \
--enable-libtwolame \
--enable-libsoxr \
--enable-libopus \
--disable-filters \
--enable-filter=$CONFIGURE_AUDFILTER_LIST \
--enable-small \
--disable-mediafoundation \
--pkg-config-flags="--static" \
--extra-cflags="${BUILD_CCFLAGS} -Os -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
elif [ $BUILD_EXE = "TRUE" ]; then
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
--prefix=${BUILD_DIR}/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH \
$PKG_CONFIG_FLAGS \
--arch="${FFMPEG_ARCH}" \
--target-os="mingw32" \
--enable-version3 \
--disable-debug \
--disable-shared \
--disable-doc \
$SWSCALE_ARG \
$FFMPEG_DISABLE_ASM \
$ENCODER_LIBS \
$GPL_LIBS \
--disable-outdevs \
--disable-amd3dnow \
--disable-amd3dnowext \
--disable-xop \
--disable-fma4 \
--disable-w32threads \
$FFMPEG5_CUDA_DISABLE_FLAGS \
--enable-pthreads \
--enable-bsfs \
--enable-filters \
--enable-swresample \
--disable-decoder=vorbis \
--enable-libvorbis \
--enable-libspeex \
--enable-libmp3lame \
--enable-libtwolame \
--enable-fontconfig \
--enable-libfribidi \
--enable-libfreetype \
--enable-libsoxr \
--enable-libopus \
--enable-libass \
--enable-libdav1d \
--enable-libvpl \
--enable-libvpx \
--enable-libglslang \
--enable-libzimg \
--enable-libplacebo \
--enable-ffnvcodec \
--enable-nvdec \
--enable-cuvid \
--disable-mediafoundation \
--pkg-config-flags="--static" \
--enable-libaribcaption \
--enable-libaribb24 \
--extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
else
PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
--prefix=${BUILD_DIR}/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH \
$PKG_CONFIG_FLAGS \
--arch="${FFMPEG_ARCH}" \
--target-os="mingw32" \
--enable-version3 \
--disable-doc \
$SWSCALE_ARG \
$FFMPEG_DISABLE_ASM \
$GPL_LIBS \
$ENCODER_LIBS \
--disable-outdevs \
--disable-debug \
--disable-static \
--disable-amd3dnow \
--disable-amd3dnowext \
--disable-xop \
--disable-fma4 \
--disable-aesni \
--disable-w32threads \
--disable-dxva2 \
--disable-d3d11va \
$FFMPEG5_CUDA_DISABLE_FLAGS \
--enable-pthreads \
--enable-bsfs \
--enable-swresample \
--enable-shared \
--disable-decoder=vorbis \
--enable-libvorbis \
--enable-libspeex \
--enable-libmp3lame \
--enable-libtwolame \
--enable-fontconfig \
--enable-libfribidi \
--enable-libfreetype \
--enable-libsoxr \
--enable-libopus \
--enable-libbluray \
--enable-libass \
--enable-libdav1d \
--enable-libvpl \
--enable-libvpx \
--enable-ffnvcodec \
--enable-nvdec \
--enable-cuvid \
--disable-mediafoundation \
--pkg-config-flags="--static" \
--enable-libaribcaption \
--enable-libaribb24 \
--extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
fi
make clean && make -j$NJOBS && make install

mkdir -p $BUILD_DIR/$FFMPEG_DIR_NAME/include
mkdir -p $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $BUILD_DIR/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH/include/* $BUILD_DIR/$FFMPEG_DIR_NAME/include
cp -f -r $BUILD_DIR/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH/bin/*     $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $BUILD_DIR/$FFMPEG_DIR_NAME/tmp/$TARGET_ARCH/lib/*     $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
rm -rf   $BUILD_DIR/$FFMPEG_DIR_NAME/tmp

cp -f -r $BUILD_DIR/$TARGET_ARCH/libass_dll/libass/libass-*.dll $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $BUILD_DIR/$TARGET_ARCH/libass_dll/libass/libass-*.def $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $BUILD_DIR/$TARGET_ARCH/libass_dll/libass/libass-*.lib $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $INSTALL_DIR/include/ass $BUILD_DIR/$FFMPEG_DIR_NAME/include

cp -f -r $BUILD_DIR/$TARGET_ARCH/libplacebo_dll/build/src/libplacebo-*.dll $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $BUILD_DIR/$TARGET_ARCH/libplacebo_dll/build/src/libplacebo-*.def $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $BUILD_DIR/$TARGET_ARCH/libplacebo_dll/build/src/libplacebo-*.lib $BUILD_DIR/$FFMPEG_DIR_NAME/lib/$VC_ARCH
cp -f -r $INSTALL_DIR/include/libplacebo $BUILD_DIR/$FFMPEG_DIR_NAME/include

cd $BUILD_DIR/src
SRC_7Z_FILENAME=ffmpeg_lgpl_src.7z
SRC_GPL_LIBS=
SRC_EXE_LIBS=
SRC_ENCODER_LIBS=
if [ ${ENABLE_GPL} != "FALSE" ]; then
  SRC_7Z_FILENAME=ffmpeg_gpl_src.7z
  SRC_GPL_LIBS="$BUILD_DIR/src/x264* $BUILD_DIR/src/x265* $BUILD_DIR/src/xvidcore*"
fi
if [ $TARGET_ARCH != "x86" ]; then
    SRC_ENCODER_LIBS="$BUILD_DIR/src/svt-av1* $BUILD_DIR/src/vvenc*"
fi
rm -f ${SRC_7Z_FILENAME}
echo "compressing src file..."
7z a -y -t7z -mx=9 -mmt=off -x\!'*.tar.gz' -x\!'*.tar.bz2' -x\!'*.zip' -x\!'*.tar.xz' -xr\!'.git' ${SRC_7Z_FILENAME} \
 $BUILD_DIR/src/ffmpeg* $BUILD_DIR/src/opus* $BUILD_DIR/src/libogg* $BUILD_DIR/src/libvorbis* \
 $BUILD_DIR/src/lame* $BUILD_DIR/src/libsndfile* $BUILD_DIR/src/twolame* $BUILD_DIR/src/soxr* $BUILD_DIR/src/speex* \
 $BUILD_DIR/src/expat* $BUILD_DIR/src/freetype* $BUILD_DIR/src/libiconv* $BUILD_DIR/src/fontconfig* \
 $BUILD_DIR/src/libpng* $BUILD_DIR/src/libass* $BUILD_DIR/src/bzip2* $BUILD_DIR/src/libbluray* \
 $BUILD_DIR/src/glslang* $BUILD_DIR/src/zimg* \
 $BUILD_DIR/src/aribb24* $BUILD_DIR/src/libaribcaption* $BUILD_DIR/src/libxml2* $BUILD_DIR/src/dav1d* \
 $BUILD_DIR/src/libvpl* $BUILD_DIR/src/libvpx* $BUILD_DIR/src/nv-codec-headers* \
 $BUILD_DIR/src/libxxhash* $BUILD_DIR/src/shaderc* $BUILD_DIR/src/SPIRV-Cross* \
 $BUILD_DIR/src/dovi_tool* $BUILD_DIR/src/libjpeg-* $BUILD_DIR/src/lcms2* $BUILD_DIR/src/libplacebo* $BUILD_DIR/src/Vulkan-Loader* \
 $SRC_GPL_LIBS $SRC_EXE_LIBS $SRC_ENCODER_LIBS \
 $PATCHES_DIR/* \
  > /dev/null
