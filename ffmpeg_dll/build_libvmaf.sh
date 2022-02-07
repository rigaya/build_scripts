#!/bin/bash
#MSYS2�pffmpeg dll�r���h�X�N���v�g
#Visual Studio�ւ̊��ϐ���ʂ��Ă�������
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools
#pacman -S p7zip git nasm python unzip
#���ʂ�pacman -S meson�Ƃ��Ƃ��܂�dav1d���r���h�ł��Ȃ��̂Œ���
#pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson
#pacman -S mingw32/mingw-w64-i686-python-lxml mingw64/mingw-w64-x86_64-python-lxml
#���̂ق���cmake(windows��)�̃C���X�g�[�����K�v
NJOBS=$NUMBER_OF_PROCESSORS
BUILD_DIR=$HOME/build_libvmaf

mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src

# [ "x86", "x64" ]
if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
else
    TARGET_ARCH="x64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ $TARGET_ARCH = "x64" ]; then
    BUILD_CCFLAGS="-mtune=skylake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
elif [ $TARGET_ARCH = "x86" ]; then
    BUILD_CCFLAGS="-m32 -mtune=skylake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -mstackrealign -I${INSTALL_DIR}/include"
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
else
    echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
    exit
fi

#--- �\�[�X�̃_�E�����[�h ---------------------------------------
if [ ! -d "vmaf_2.3.0" ]; then
    wget -O vmaf_2.3.0.tar.gz https://github.com/Netflix/vmaf/archive/refs/tags/v2.3.0.tar.gz
    tar xf vmaf_2.3.0.tar.gz
fi


# --- �o�͐������ --------------------------------------
if [ ! -d $BUILD_DIR/$TARGET_ARCH ]; then
    mkdir $BUILD_DIR/$TARGET_ARCH
fi
# --- �o�͐�̌Â��f�[�^���폜 ----------------------
cd $BUILD_DIR/$TARGET_ARCH
if [ -d vmaf ]; then
    rm -rf vmaf
fi
# -- vmaf�̃r���h -----------------------------------
find ../src/ -type d -name "vmaf-*" | xargs -i cp -r {} ./vmaf
cd vmaf/libvmaf
sed -i "s/subdir('tools')/# subdir('tools')/g" meson.build
CC=gcc \
CXX=g++ \
CFLAGS="${BUILD_CCFLAGS}" \
CPPFLAGS="${BUILD_CCFLAGS}" \
LDFLAGS="${BUILD_LDFLAGS}" \
meson setup --backend=ninja --default-library=shared --buildtype=release --prefix=$INSTALL_DIR -Denable_tests=false -Denable_docs=false build
ninja -vC build install
# vmaf �̃C���|�[�g���C�u�����̍쐬
cd $INSTALL_DIR/bin
gendef libvmaf.dll
LIBVMAF_LIB_FILENAME=libvmaf.lib
LIBVMAF_DEF_FILENAME=libvmaf.def
lib.exe -machine:$TARGET_ARCH -def:$LIBVMAF_DEF_FILENAME -out:$LIBVMAF_LIB_FILENAME

cd $BUILD_DIR/src
rm -f vmaf_src.7z
echo "compressing src file..."
7z a -y -t7z -mx=9 -myx=9 -mmt=off -x\!'*.tar.gz' -x\!'*.tar.bz2' -x\!'*.zip' -x\!'*.tar.xz' -xr\!'.git' -xr\!'doc' -xr\!'docs' vmaf_src.7z \
 $BUILD_DIR/src/vmaf*/libvmaf \
  > /dev/null

