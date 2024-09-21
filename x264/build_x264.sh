#!/bin/sh
# msys2用x264ビルドスクリプト
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain
#pacman -S p7zip git nasm
BUILD_DIR=`pwd`/build_x264
BUILD_CCFLAGS="-flto -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -fno-ident -I${INSTALL_DIR}/include" 
BUILD_LDFLAGS="-flto -static -static-libgcc -Wl,--gc-sections -Wl,--strip-all -L${INSTALL_DIR}/lib"
MAKE_PROCESS=$NUMBER_OF_PROCESSORS
Y4M_PATH=$HOME/sakura_op_cut.y4m
X264_MAKEFILE_PATCH="`pwd`/patch/x264_makefile.diff"
PROFILE_GEN_CC="-fprofile-generate -gline-tables-only"
PROFILE_GEN_LD="-fprofile-generate -gline-tables-only"
PROFILE_USE_CC="-fprofile-use"
PROFILE_USE_LD="-fprofile-use"

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

if [ $MSYSTEM == "CLANG64" ]; then
    export CC=clang
    export CXX=clang++
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

if [ -d "x264" ]; then
    cd x264
    git pull
    cd ..
else
	git clone https://code.videolan.org/videolan/x264.git
fi

if [ -d "l-smash" ]; then
    cd l-smash
    git pull
    cd ..
else
	git clone https://github.com/l-smash/l-smash.git l-smash
fi

mkdir -p $BUILD_DIR/$TARGET_ARCH
cd $BUILD_DIR/$TARGET_ARCH
if [ -d "x264" ]; then
    rm -rf x264
fi
cp -r ../src/x264 x264

if [ -d "l-smash" ]; then
    rm -rf l-smash
fi
cp -r ../src/l-smash l-smash

if [ ! -e $Y4M_PATH ]; then
	tar xf $Y4M_XZ_PATH -C `dirname $Y4M_PATH`
fi

#build L-SMASH
cd $BUILD_DIR/$TARGET_ARCH/L-SMASH
./configure \
--prefix=$INSTALL_DIR \
--cc=${CC} \
--extra-cflags="${BUILD_CCFLAGS}" \
--extra-ldflags="${BUILD_LDFLAGS}"
sed -i -e 's/^STRIP = .\+/STRIP =/g' config.mak
make clean && make -j$MAKE_PROCESS install-lib

#build x264
echo "Start build x264(${TARGET_ARCH})"
cd $BUILD_DIR/$TARGET_ARCH/x264
X264_REV=`git rev-list HEAD | wc -l`
patch < $X264_MAKEFILE_PATCH
export X264_REV=$X264_REV

PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
 --prefix=$INSTALL_DIR \
 --host=$MINGW_CHOST \
 --disable-strip \
 --disable-ffms \
 --disable-gpac \
 --disable-lavf \
 --bit-depth=all \
 --extra-cflags="-O3 ${BUILD_CCFLAGS} ${PROFILE_GEN_CC}" \
 --extra-ldflags="${BUILD_LDFLAGS} ${PROFILE_GEN_LD}"
make -j$MAKE_PROCESS

prof_files=()
prof_idx=0

function run_prof() {
    ./x264 $@
    prof_idx=$((prof_idx + 1))
    for file in default_*_0.profraw; do
      new_file="${file%.profraw}_${prof_idx}.${file##*.}"
      mv "$file" "$new_file"
      echo ${new_file}
      prof_files+=( ${new_file} )
    done
}

run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --crf 30 -b1 -m1 -r1 --me dia --no-cabac --direct temporal --ssim --no-weightb
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --crf 16 -b2 -m3 -r3 --me hex --no-8x8dct --direct spatial --no-dct-decimate -t0  --slice-max-mbs 50
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --crf 26 -b4 -m5 -r2 --me hex --cqm jvt --nr 100 --psnr --no-mixed-refs --b-adapt 2 --slice-max-size 1500
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --crf 18 -b3 -m9 -r5 --me umh -t1 -A all --b-pyramid normal --direct auto --no-fast-pskip --no-mbtree
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --crf 22 -b3 -m7 -r4 --me esa -t2 -A all --psy-rd 1.0:1.0 --slices 4
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --frames 50 --crf 24 -b3 -m10 -r3 --me tesa -t2
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --frames 50 -q0 -m9 -r2 --me hex -Aall
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --frames 50 -q0 -m2 -r1 --me hex --no-cabac
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --crf 30 -b1 -m1 -r1 --me dia --no-cabac --direct temporal --ssim --no-weightb
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --crf 16 -b2 -m3 -r3 --me hex --no-8x8dct --direct spatial --no-dct-decimate -t0  --slice-max-mbs 50
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --crf 26 -b4 -m5 -r2 --me hex --cqm jvt --nr 100 --psnr --no-mixed-refs --b-adapt 2 --slice-max-size 1500
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --crf 18 -b3 -m9 -r5 --me umh -t1 -A all --b-pyramid normal --direct auto --no-fast-pskip --no-mbtree
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --crf 22 -b3 -m7 -r4 --me esa -t2 -A all --psy-rd 1.0:1.0 --slices 4
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --frames 50 --crf 24 -b3 -m10 -r3 --me tesa -t2
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --frames 50 -q0 -m9 -r2 --me hex -Aall
run_prof "${Y4M_PATH}" -o /dev/null --asm avx2 --output-depth 10 --frames 50 -q0 -m2 -r1 --me hex --no-cabac

run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --crf 30 -b1 -m1 -r1 --me dia --no-cabac --direct temporal --ssim --no-weightb
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --crf 16 -b2 -m3 -r3 --me hex --no-8x8dct --direct spatial --no-dct-decimate -t0  --slice-max-mbs 50
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --crf 26 -b4 -m5 -r2 --me hex --cqm jvt --nr 100 --psnr --no-mixed-refs --b-adapt 2 --slice-max-size 1500
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --crf 18 -b3 -m9 -r5 --me umh -t1 -A all --b-pyramid normal --direct auto --no-fast-pskip --no-mbtree
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --crf 22 -b3 -m7 -r4 --me esa -t2 -A all --psy-rd 1.0:1.0 --slices 4
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --frames 50 --crf 24 -b3 -m10 -r3 --me tesa -t2
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --frames 50 -q0 -m9 -r2 --me hex -Aall
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --frames 50 -q0 -m2 -r1 --me hex --no-cabac
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --crf 30 -b1 -m1 -r1 --me dia --no-cabac --direct temporal --ssim --no-weightb
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --crf 16 -b2 -m3 -r3 --me hex --no-8x8dct --direct spatial --no-dct-decimate -t0  --slice-max-mbs 50
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --crf 26 -b4 -m5 -r2 --me hex --cqm jvt --nr 100 --psnr --no-mixed-refs --b-adapt 2 --slice-max-size 1500
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --crf 18 -b3 -m9 -r5 --me umh -t1 -A all --b-pyramid normal --direct auto --no-fast-pskip --no-mbtree
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --crf 22 -b3 -m7 -r4 --me esa -t2 -A all --psy-rd 1.0:1.0 --slices 4
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --frames 50 --crf 24 -b3 -m10 -r3 --me tesa -t2
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --frames 50 -q0 -m9 -r2 --me hex -Aall
run_prof "${Y4M_PATH}" -o /dev/null --asm avx512 --output-depth 10 --frames 50 -q0 -m2 -r1 --me hex --no-cabac

echo ${prof_files[@]}
llvm-profdata merge -output=default.profdata "${prof_files[@]}"

PROFILE_USE_CC=${PROFILE_USE_CC}=`pwd`/default.profdata
PROFILE_USE_LD=${PROFILE_USE_LD}=`pwd`/default.profdata

PKG_CONFIG_PATH=${INSTALL_DIR}/lib/pkgconfig \
./configure \
 --prefix=$INSTALL_DIR \
 --host=$MINGW_CHOST \
 --enable-strip \
 --disable-ffms \
 --disable-gpac \
 --disable-lavf \
 --bit-depth=all \
 --extra-cflags="-O3 ${BUILD_CCFLAGS} ${PROFILE_USE_CC}" \
 --extra-ldflags="${BUILD_LDFLAGS} ${PROFILE_USE_LD}"
make -j$MAKE_PROCESS

cp -f x264.exe x264_${X264_REV}_$TARGET_ARCH.exe
