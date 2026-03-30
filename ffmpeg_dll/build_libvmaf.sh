#!/bin/bash

set -e

if [ "${MSYSTEM:-}" = "MINGW32" ] || [ "${MSYSTEM:-}" = "MINGW64" ]; then
    BUILD_MODE="msys2"
    if [ "${MSYSTEM:-}" = "MINGW32" ]; then
        TARGET_ARCH="x86"
    else
        TARGET_ARCH="x64"
    fi
    BUILD_DIR=$HOME/build_libvmaf
    SRC_DIR=${BUILD_DIR}/src
    INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build
    if [ $TARGET_ARCH = "x64" ]; then
        BUILD_CCFLAGS="-mtune=skylake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
        BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
    elif [ $TARGET_ARCH = "x86" ]; then
        BUILD_CCFLAGS="-m32 -mtune=skylake -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -mstackrealign -I${INSTALL_DIR}/include"
        BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -static -static-libgcc -static-libstdc++ -L${INSTALL_DIR}/lib"
    else
        echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
        exit 1
    fi
else
    BUILD_MODE="linux"
    WORK_DIR=`pwd`
    SRC_DIR=${WORK_DIR}/src
    TARGET_DIR=${WORK_DIR}/build_libvmaf
    BUILD_DIR=${TARGET_DIR}
    case "$(uname -m)" in
        x86_64|amd64)
            TARGET_ARCH="x64"
            ;;
        i686|i386)
            TARGET_ARCH="x86"
            ;;
        aarch64|arm64)
            TARGET_ARCH="arm64"
            ;;
        *)
            echo "Unsupported host architecture: $(uname -m)"
            exit 1
            ;;
    esac
    INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build
    TUNE_FLAG=""
    if [ "$TARGET_ARCH" = "x86" ] || [ "$TARGET_ARCH" = "x64" ]; then
        for target_arch in alderlake skylake; do
            if echo 'int main(){return 0;}' | \
                "${CC:-gcc}" -x c - -c -mtune=${target_arch} -o /dev/null >/dev/null 2>&1; then
                TUNE_FLAG="-mtune=${target_arch}"
                break
            fi
        done
    fi
    if [ "$TARGET_ARCH" = "x64" ]; then
        BUILD_CCFLAGS="${TUNE_FLAG} -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
    elif [ "$TARGET_ARCH" = "x86" ]; then
        BUILD_CCFLAGS="${TUNE_FLAG} -m32 -msse2 -fexcess-precision=fast -mfpmath=sse -ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -mstackrealign -I${INSTALL_DIR}/include"
    elif [ "$TARGET_ARCH" = "arm64" ]; then
        BUILD_CCFLAGS="-ffast-math -fomit-frame-pointer -ffunction-sections -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
    else
        echo "invalid TARGET_ARCH: ${TARGET_ARCH}"
        exit 1
    fi
    BUILD_LDFLAGS="-Wl,--gc-sections -Wl,--strip-all -L${INSTALL_DIR}/lib"
fi

mkdir -p "$BUILD_DIR"
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

if [ ! -d "vmaf_2.3.0" ]; then
    wget -O vmaf_2.3.0.tar.gz https://github.com/Netflix/vmaf/archive/refs/tags/v2.3.0.tar.gz
    tar xf vmaf_2.3.0.tar.gz
fi

mkdir -p "$BUILD_DIR/$TARGET_ARCH"
cd "$BUILD_DIR/$TARGET_ARCH"
if [ -d vmaf ]; then
    rm -rf vmaf
fi

VMAF_SRC_DIR=$(find "$SRC_DIR" -maxdepth 1 -type d -name "vmaf-*" | head -n 1)
if [ -z "$VMAF_SRC_DIR" ]; then
    echo "vmaf source not found under ${SRC_DIR}"
    exit 1
fi
cp -r "$VMAF_SRC_DIR" ./vmaf
cd vmaf/libvmaf
sed -i "s/subdir('tools')/# subdir('tools')/g" meson.build
rm -rf build

if [ "$BUILD_MODE" = "linux" ]; then
    CC=${CC:-gcc} \
    CXX=${CXX:-g++} \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    meson setup --backend=ninja --default-library=static --buildtype=release --prefix="$INSTALL_DIR" --libdir=lib -Denable_tests=false -Denable_docs=false build
    ninja -vC build install
else
    CC=${CC:-gcc} \
    CXX=${CXX:-g++} \
    CFLAGS="${BUILD_CCFLAGS}" \
    CPPFLAGS="${BUILD_CCFLAGS}" \
    LDFLAGS="${BUILD_LDFLAGS}" \
    meson setup --backend=ninja --default-library=shared --buildtype=release --prefix="$INSTALL_DIR" -Denable_tests=false -Denable_docs=false build
    ninja -vC build install

    cd "$INSTALL_DIR/bin"
    gendef libvmaf.dll
    LIBVMAF_LIB_FILENAME=libvmaf.lib
    LIBVMAF_DEF_FILENAME=libvmaf.def
    lib.exe -machine:$TARGET_ARCH -def:$LIBVMAF_DEF_FILENAME -out:$LIBVMAF_LIB_FILENAME
fi

cd "$SRC_DIR"
if command -v 7z >/dev/null 2>&1; then
    rm -f vmaf_src.7z
    echo "compressing src file..."
    7z a -y -t7z -mx=9 -myx=9 -mmt=off -x\!'*.tar.gz' -x\!'*.tar.bz2' -x\!'*.zip' -x\!'*.tar.xz' -xr\!'.git' -xr\!'doc' -xr\!'docs' vmaf_src.7z \
     "$SRC_DIR"/vmaf*/libvmaf \
      > /dev/null
fi
