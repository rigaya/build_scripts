#!/bin/sh
# msys2用x264afsビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=`pwd`/build_x264
Y4M_PATH="`pwd`/husky.y4m"
Y4M_XZ_PATH="`pwd`/husky.tar.xz"
X264_MAKEFILE_PATCH="`pwd`/patch/x264_makefile.diff"
X264_AFS_PATCH_DIR="`pwd`/patch/afs"
BUILD_CCFLAGS="-m32 -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include" 
BUILD_CCFLAGS_FFMPEG="-Os -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include"
BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -L${INSTALL_DIR}/lib"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
BUILD_ALL=1

#download
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src
git config --global core.autocrlf false

if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
    FFMPEG_ARCH="i686"
else
    TARGET_ARCH="x64"
    FFMPEG_ARCH="x86_64"
	echo "x264afs not for x64 build!"
	exit 1
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ -d "x264" ]; then
    cd x264
    git pull
    cd ..
else
	git clone git://git.videolan.org/x264.git x264
fi

if [ -d "l-smash" ]; then
    cd l-smash
    git pull
    cd ..
else
	git clone https://github.com/l-smash/l-smash.git l-smash
fi

if [ -d "ffmpeg" ]; then
    cd ffmpeg
    git pull
    cd ..
else
	git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
fi

if [ ! -e $Y4M_PATH ]; then
	tar xf $Y4M_XZ_PATH -C `dirname $Y4M_PATH`
fi


#copy for x86
mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "x264afs" ]; then
    rm -rf x264afs
fi
cp -r ../src/x264 x264afs

if [ -d "l-smash" ]; then
    rm -rf l-smash
fi
cp -r ../src/l-smash l-smash

if [ -d "ffmpeg" ]; then
    rm -rf ffmpeg
fi
cp -r ../src/ffmpeg ffmpeg

#build ffmpeg
#if [ $BUILD_ALL -ne 0 ]; then
	cd $BUILD_DIR/$TARGET_ARCH/ffmpeg
	PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
	./configure \
	--prefix=$INSTALL_DIR \
	--arch=${FFMPEG_ARCH} \
	--target-os="mingw32" \
	--enable-gpl \
	--enable-runtime-cpudetect \
	--enable-w32threads \
	--disable-pthreads \
	--disable-programs \
	--disable-doc \
	--disable-muxers \
	--disable-encoders \
	--disable-postproc \
	--disable-avdevice \
	--disable-avfilter \
	--disable-hwaccels \
	--disable-filters \
	--disable-network \
	--disable-devices \
	--disable-debug \
	--disable-protocols \
	--enable-protocol=file,pipe \
	--disable-bzlib \
	--disable-zlib \
	--disable-amd3dnow \
	--disable-amd3dnowext \
	--disable-xop \
	--disable-fma4 \
	--enable-small \
	--extra-cflags="${BUILD_CCFLAGS_FFMPEG}" \
	--extra-ldflags="${BUILD_LDFLAGS} -L${INSTALL_DIR}/lib"
	make clean && make -j$MAKE_PROCESS && make install
#fi

#build L-SMASH
cd $BUILD_DIR/$TARGET_ARCH/L-SMASH
LSMASH_REV=`git rev-list HEAD | wc -l`
export LSMASH_REV=$LSMASH_REV
./configure \
--prefix=$INSTALL_DIR \
--extra-cflags="${BUILD_CCFLAGS}" \
--extra-ldflags="${BUILD_LDFLAGS}"
make clean && make -j$MAKE_PROCESS install-lib

#build x264afs
cd $BUILD_DIR/$TARGET_ARCH/x264afs
X264_REV=`git rev-list HEAD | wc -l`
export X264_REV=$X264_REV

patch -uNp1 < "${X264_AFS_PATCH_DIR}/afs.diff"
cp "${X264_AFS_PATCH_DIR}/afs_client.h" .
cp "${X264_AFS_PATCH_DIR}/util.h" .

PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
 --prefix=$INSTALL_DIR \
 --host=$MINGW_CHOST \
 --enable-strip \
 --disable-ffms \
 --disable-gpac \
 --extra-cflags="${BUILD_CCFLAGS}" \
 --extra-ldflags="${BUILD_LDFLAGS}"
# make -j$MAKE_PROCESS
make fprofiled VIDS="${Y4M_PATH}" -j$MAKE_PROCESS
cp -f x264.exe x264afs_r${X264_REV}+${LSMASH_REV}.exe
