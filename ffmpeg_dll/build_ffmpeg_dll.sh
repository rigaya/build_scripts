#!/bin/bash
#MSYS2用ffmpeg dllビルドスクリプト
# 下記インストールでgcc13系を持つmsys2を導入する (updateしてgcc14にしないこと、なぜか動作しないバイナリができる)
# https://repo.msys2.org/distrib/x86_64/msys2-x86_64-20230526.exe
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
NJOBS=$NUMBER_OF_PROCESSORS
PATCHES_DIR=$HOME/patches

BUILD_ALL="FALSE"
SSE4_2="FALSE"
UPDATE_FFMPEG="FALSE"
ENABLE_SWSCALE="FALSE"
FOR_FFMPEG4="FALSE"
FOR_AUDENC="FALSE"
ADD_TLVMMT="FALSE"
BUILD_EXE="FALSE"

# [ bitrate, swscale, exe ]
TARGET_BUILD=""


while getopts "ast:urm" OPT
do
  case $OPT in
    "a" ) BUILD_ALL="TRUE" ;;
    "s" ) SSE4_2="TRUE" ;;
    "t" ) TARGET_BUILD=$OPTARG ;;
    "u" ) UPDATE_FFMPEG="TRUE" ;;
    "r" ) FOR_FFMPEG4="TRUE" ;;
    "m" ) ADD_TLVMMT="TRUE" ;;
  esac
done


if [ "$FOR_FFMPEG4" = "TRUE" ]; then
    BUILD_DIR=$HOME/build_ffmpeg4_dll
else
    BUILD_DIR=$HOME/build_ffmpeg_dll
fi

echo FOR_FFMPEG4=$FOR_FFMPEG4
echo BUILD_DIR=$BUILD_DIR

mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src

if [ "$TARGET_BUILD" = "swscale" ]; then
    ENABLE_SWSCALE="TRUE"
elif [ "$TARGET_BUILD" = "audenc" ]; then
    FOR_AUDENC="TRUE"
    BUILD_EXE="TRUE"
elif [ "$TARGET_BUILD" = "exe" ]; then
    BUILD_EXE="TRUE"
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
if [ $TARGET_ARCH = "x64" ]; then
    BUILD_CCFLAGS="-mtune=alderlake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
elif [ $TARGET_ARCH = "x86" ]; then
    BUILD_CCFLAGS="-m32 -mtune=alderlake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -mstackrealign -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
    #  libavcodec/h264_cabac.c: In function 'ff_h264_decode_mb_cabac': libavcodec/x86/cabac.h:192:5: error: 'asm' operand has impossible 対策
    FFMPEG_DISABLE_ASM="--disable-inline-asm"
else
    echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
    exit
fi

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

#--- ソースのダウンロード ---------------------------------------
if [ "$FOR_FFMPEG4" = "TRUE" ]; then
    if [ ! -d "ffmpeg" ]; then
        wget https://ffmpeg.org/releases/ffmpeg-4.4.3.tar.xz
        tar xf ffmpeg-4.4.3.tar.xz
        mv ffmpeg-4.4.3 ffmpeg
    fi
elif [ -d "ffmpeg" ]; then
    if [ $UPDATE_FFMPEG != "FALSE" ]; then
        cd ffmpeg
        make uninstall && make distclean &> /dev/null
        cd ..
        if [ ! -d "ffmpeg/.git" ]; then
            rm -rf ffmpeg
            git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
        fi
        cd ffmpeg
        git fetch
        git reset --hard
        git checkout -b build 9d15fe77e33b757c75a4186fa049857462737713
        cd ..
        #wget https://ffmpeg.org/releases/ffmpeg-7.0.tar.xz
        #tar xf ffmpeg-7.0.tar.xz
        #mv ffmpeg-7.0 ffmpeg
        #wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
        #tar xf ffmpeg-snapshot.tar.bz2
    fi
else
    wget https://ffmpeg.org/releases/ffmpeg-7.0.tar.xz
    tar xf ffmpeg-7.0.tar.xz
    mv ffmpeg-7.0 ffmpeg
fi

if [ ! -d "libpng-1.6.43" ]; then
    wget https://download.sourceforge.net/libpng/libpng-1.6.43.tar.xz
    tar xf libpng-1.6.43.tar.xz
fi

if [ ! -d "bzip2-1.0.8" ]; then
    wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
    tar xf bzip2-1.0.8.tar.gz
fi

if [ ! -d "expat-2.6.2" ]; then
    wget https://github.com/libexpat/libexpat/releases/download/R_2_6_2/expat-2.6.2.tar.xz
    tar xf expat-2.6.2.tar.xz
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

if [ ! -d "fribidi-1.0.11" ]; then
    wget https://github.com/fribidi/fribidi/releases/download/v1.0.11/fribidi-1.0.11.tar.xz
    tar xf fribidi-1.0.11.tar.xz
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

if [ ! -d "libogg-1.3.5" ]; then
    wget https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.xz
    tar xf libogg-1.3.5.tar.xz
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

if [ ! -d "libxml2-2.12.6" ]; then
    wget -O libxml2-2.12.6.tar.gz https://github.com/GNOME/libxml2/archive/refs/tags/v2.12.6.tar.gz
    tar xf libxml2-2.12.6.tar.gz
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

if [ ! -d "libvpl-2.12.0" ]; then
    wget -O libvpl-2.12.0.tar.gz https://github.com/intel/libvpl/archive/refs/tags/v2.12.0.tar.gz
    tar xf libvpl-2.12.0.tar.gz
fi

if [ ! -d "nv-codec-headers-12.2.72.0" ]; then
    wget https://github.com/FFmpeg/nv-codec-headers/releases/download/n12.2.72.0/nv-codec-headers-12.2.72.0.tar.gz
    tar xf nv-codec-headers-12.2.72.0.tar.gz
fi

if [ ! -d "libvpx-1.14.1" ]; then
    wget -O libvpx-1.14.1.tar.gz https://github.com/webmproject/libvpx/archive/refs/tags/v1.14.1.tar.gz
    tar xf libvpx-1.14.1.tar.gz
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

if [ ! -d "dav1d-1.4.3" ]; then
    wget https://code.videolan.org/videolan/dav1d/-/archive/1.4.3/dav1d-1.4.3.tar.gz
    tar xf dav1d-1.4.3.tar.gz
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
    echo "Patch ffmpeg_tlvmmt_access_group_desc.diff..."
    patch -p1 < $PATCHES_DIR/ffmpeg_tlvmmt_access_group_desc.diff
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
    --without-docbook
    make -j$NJOBS && make install
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "freetype" ]; then
    find ../src/ -type d -name "freetype-*" | xargs -i cp -r {} ./freetype
    #msys側のzlib(zlib.h, zconf.h, libz.a, libz.pcを消さないとうまくいかない)
    #あるいはconfigure後に、build/unix/unix-cc.mk内の
    #CFLAGSから-IC:/.../MSYS/includeとLDFLAGSの-LC:/.../MSYS/libを消す
    cd ./freetype
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
    --with-zlib=no \
    --with-bzip2=yes
    make -j$NJOBS && make install
    sed -i -e "s/ -lfreetype$/ -lfreetype -liconv -lpng -lbz2 -lz/g" $INSTALL_DIR/lib/pkgconfig/freetype2.pc
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "libiconv" ]; then
    find ../src/ -type d -name "libiconv-*" | xargs -i cp -r {} ./libiconv
    cd ./libiconv
    gzip -dc $PATCHES_DIR/libiconv-1.16-ja-1.patch.gz | patch -p1
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    CFLAGS="${BUILD_CCFLAGS_SMALL}" \
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
    cmake -G "MSYS Makefiles" \
    -D BUILD_SHARED_LIBS:BOOL=FALSE \
    -D CMAKE_C_FLAGS_RELEASE:STRING="${BUILD_CCFLAGS}" \
    -D CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING="${BUILD_LDFLAGS}" \
    -D WITH_OPENMP:BOOL=NO \
    -D BUILD_TESTS:BOOL=NO \
    -D CMAKE_INSTALL_PREFIX=$INSTALL_DIR \
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
    sed -i -e "s/-lC:\/ProgramAnother\/msys64\/${MINGWDIR}\/lib\/libstdc++.a/-lstdc++/g" ${INSTALL_DIR}/lib/pkgconfig/libaribcaption.pc
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

cd $BUILD_DIR/$TARGET_ARCH/ffmpeg_test
if [ ! -e ./ffmpeg.exe ]; then
    PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
    ./configure \
    --prefix=${INSTALL_DIR}/$FFMPEG_DIR_NAME \
    --arch="${FFMPEG_ARCH}" \
    --target-os="mingw32" \
    $FFMPEG_DISABLE_ASM \
    --disable-doc \
    --disable-avdevice \
    --disable-hwaccels \
    --disable-devices \
    --disable-debug \
    --disable-network \
    --disable-amd3dnow \
    --disable-amd3dnowext \
    --disable-xop \
    --disable-fma4 \
    --disable-bsfs \
    --disable-aesni \
    --enable-libvorbis \
    --enable-libspeex \
    --enable-libmp3lame \
    --enable-libtwolame \
    --enable-libsoxr \
    --enable-libopus \
    --extra-cflags="${BUILD_CCFLAGS} -I${INSTALL_DIR}/include ${FFMPEG_SSE}" \
    --extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
    make -j$NJOBS
fi

./ffmpeg.exe -encoders | grep '^ A.\{5\} ' | cut -d' ' -f3 > ffmpeg_audenc_list.txt
./ffmpeg.exe -encoders | grep '^ S.\{5\} ' | cut -d' ' -f3 >> ffmpeg_audenc_list.txt
./configure --list-encoders | tr '\t' '\n' | grep -v '^\s*$' | sort > ./configure_enc_list.txt
CONFIGURE_AUDENC_LIST=`python $HOME/build_get_audlist.py ffmpeg_audenc_list.txt ./configure_enc_list.txt`

./ffmpeg.exe -filters | grep -v 'V->' | grep -v '\->V' | cut -d' ' -f3 > ffmpeg_audfilter_list.txt
./configure --list-filters | tr '\t' '\n' | grep -v '^\s*$' | sort > ./configure_filter_list.txt
CONFIGURE_AUDFILTER_LIST=`python $HOME/build_get_audlist.py ffmpeg_audfilter_list.txt ./configure_filter_list.txt`

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
    FFMPEG5_CUDA_DISABLE_FLAGS=" --disable-cuda-nvcc --disable-cuda-llvm --disable-cuvid --disable-ffnvcodec --disable-nvdec --disable-nvenc "
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
--disable-postproc \
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
--enable-protocol="file,pipe" \
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
--disable-postproc \
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
--enable-ffnvcodec \
--enable-nvdec \
--enable-cuvid \
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
--disable-postproc \
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
--disable-filters \
--enable-filter=$CONFIGURE_AUDFILTER_LIST \
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

cd $BUILD_DIR/src
if [ ${UPDATE_FFMPEG} != "FALSE" ]; then
    rm -f ffmpeg_lgpl_src.7z
    echo "compressing src file..."
    7z a -y -t7z -mx=9 -mmt=off -x\!'*.tar.gz' -x\!'*.tar.bz2' -x\!'*.zip' -x\!'*.tar.xz' -xr\!'.git' ffmpeg_lgpl_src.7z \
     $BUILD_DIR/src/ffmpeg* $BUILD_DIR/src/opus* $BUILD_DIR/src/libogg* $BUILD_DIR/src/libvorbis* \
     $BUILD_DIR/src/lame* $BUILD_DIR/src/libsndfile* $BUILD_DIR/src/twolame* $BUILD_DIR/src/soxr* $BUILD_DIR/src/speex* \
     $BUILD_DIR/src/expat* $BUILD_DIR/src/freetype* $BUILD_DIR/src/libiconv* $BUILD_DIR/src/fontconfig* \
     $BUILD_DIR/src/libpng* $BUILD_DIR/src/libass* $BUILD_DIR/src/bzip2* $BUILD_DIR/src/libbluray* \
     $BUILD_DIR/src/aribb24* $BUILD_DIR/src/libaribcaption* $BUILD_DIR/src/libxml2* $BUILD_DIR/src/dav1d* \
     $BUILD_DIR/src/libvpl* $BUILD_DIR/src/libvpx* $BUILD_DIR/src/nv-codec-headers* \
     $PATCHES_DIR/* \
      > /dev/null
fi

