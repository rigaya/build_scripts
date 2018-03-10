#!/bin/sh
# msys2用x264afsビルドスクリプト
BUILD_DIR=$HOME/build_x264
Y4M_PATH="$HOME/husky.y4m"
Y4M_XZ_PATH="$HOME/husky.tar.xz"
X264_MAKEFILE_PATCH="$HOME/patch/x264_makefile.diff"
X264_AFS_PATCH_DIR="$HOME/patch/afs"
BUILD_CCFLAGS="-m32 -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include" 
BUILD_CCFLAGS_FFMPEG="-Os -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include"
BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -L${INSTALL_DIR}/lib"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
SEVEN_ZIP_PATH="/C/Program Files/7-Zip/7z.exe"
GOOGLE_DIR="/C/Users/rigaya/GoogleDrive/x264afs"
ONEDRIVE_DIR="/C/Users/rigaya/OneDrive/x264afs"
DROPBOX_DIR="/C/Users/rigaya/DropBox/x264afs"
GPL_LICENSE_PATH="/C/Users/rigaya/GoogleDrive/txt/gplv2.txt"
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
	tar xf $Y4M_XZ_PATH
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
./configure \
--prefix=$INSTALL_DIR \
--extra-cflags="${BUILD_CCFLAGS}" \
--extra-ldflags="${BUILD_LDFLAGS}"
make clean && make -j$MAKE_PROCESS install-lib

#build x264afs
cd $BUILD_DIR/$TARGET_ARCH/x264afs
X264_REV=`git rev-list HEAD | wc -l`

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

read -p "Hit enter: "

cd $HOME
mkdir -p $BUILD_DIR/temp
mkdir -p $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/x264 $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/ffmpeg $BUILD_DIR/temp/src
cp -r $BUILD_DIR/src/l-smash $BUILD_DIR/temp/src
rm -rf $BUILD_DIR/temp/src/x264/.git
rm -rf $BUILD_DIR/temp/src/ffmpeg/.git
rm -rf $BUILD_DIR/temp/src/l-smash/.git

"${SEVEN_ZIP_PATH}" a -t7z -mx=9 -mmt=off  "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" $BUILD_DIR/temp/src/

"${SEVEN_ZIP_PATH}" a -t7z -mx=9 -mmt=off "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" $BUILD_DIR/$TARGET_ARCH/x264afs/x264afs_r${X264_REV}+${LSMASH_REV}.exe ${GPL_LICENSE_PATH}

cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" "${GOOGLE_DIR}/src"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" "${ONEDRIVE_DIR}/src"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}_src.7z" "${DROPBOX_DIR}/src"

cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" "${GOOGLE_DIR}"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" "${ONEDRIVE_DIR}"
cp -f "$BUILD_DIR/temp/afsexe_r${X264_REV}+${LSMASH_REV}.7z" "${DROPBOX_DIR}"

rm -rf $BUILD_DIR/temp
