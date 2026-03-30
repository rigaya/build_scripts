#!/bin/bash
# libvmaf build script
# - MSYS2: build libvmaf.dll
# - Linux/WSL2: build static-only libvmaf.a

set -euo pipefail

SKIP_SRC_ARCHIVE="FALSE"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-src-archive) SKIP_SRC_ARCHIVE="TRUE"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
    NJOBS="${NUMBER_OF_PROCESSORS}"
else
    NJOBS="$(nproc 2>/dev/null || echo 1)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${SCRIPT_DIR}"
SRC_DIR="${WORK_DIR}/src"
BUILD_DIR="${WORK_DIR}"
VMAF_VERSION="${VMAF_VERSION:-3.0.0}"
VMAF_ARCHIVE="v${VMAF_VERSION}.tar.gz"
VMAF_URL="https://github.com/Netflix/vmaf/archive/refs/tags/${VMAF_ARCHIVE}"
VMAF_SRC_STAMP_DIR="vmaf-${VMAF_VERSION}"
LOCAL_VMAF_SRC="${REPO_ROOT}/vmaf"

mkdir -p "${BUILD_DIR}"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

if [ "${MSYSTEM:-}" = "MINGW32" ]; then
    TARGET_ARCH="x86"
    BUILD_MODE="shared"
    MINGWDIR="mingw32"
elif [ "${MSYSTEM:-}" = "MINGW64" ]; then
    TARGET_ARCH="x64"
    BUILD_MODE="shared"
    MINGWDIR="mingw64"
else
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
    BUILD_MODE="static"
    MINGWDIR=""
fi

INSTALL_DIR="${BUILD_DIR}/${TARGET_ARCH}/build"
PKG_CONFIG_DIR="${INSTALL_DIR}/lib/pkgconfig"

TUNE_FLAG=""
if [ "${TARGET_ARCH}" = "x86" ] || [ "${TARGET_ARCH}" = "x64" ]; then
    for target_arch in alderlake skylake; do
        if echo 'int main(){return 0;}' | "${CC:-gcc}" -x c - -c "-mtune=${target_arch}" -o /dev/null >/dev/null 2>&1; then
            TUNE_FLAG="-mtune=${target_arch}"
            break
        fi
    done
fi

BUILD_ARCH_CCFLAGS=""
if [ "${TARGET_ARCH}" = "x86" ] || [ "${TARGET_ARCH}" = "x64" ]; then
    BUILD_ARCH_CCFLAGS="${TUNE_FLAG} -msse2 -mfpmath=sse"
fi
BUILD_CCFLAGS="${BUILD_ARCH_CCFLAGS} -fomit-frame-pointer -fno-ident -D_FORTIFY_SOURCE=0 -I${INSTALL_DIR}/include"
BUILD_LDFLAGS="-Wl,--strip-all -L${INSTALL_DIR}/lib"
if [ "${TARGET_ARCH}" = "x86" ]; then
    BUILD_CCFLAGS="-m32 ${BUILD_CCFLAGS} -mstackrealign"
    BUILD_LDFLAGS="-m32 ${BUILD_LDFLAGS}"
fi

echo "TARGET_ARCH=${TARGET_ARCH}"
echo "BUILD_MODE=${BUILD_MODE}"
echo "SRC_DIR=${SRC_DIR}"
echo "INSTALL_DIR=${INSTALL_DIR}"

prepare_vmaf_source() {
    if [ -d "${LOCAL_VMAF_SRC}/libvmaf" ]; then
        echo "Using local source: ${LOCAL_VMAF_SRC}"
        return 0
    fi

    if [ ! -d "${VMAF_SRC_STAMP_DIR}" ]; then
        if [ ! -f "${VMAF_ARCHIVE}" ]; then
            wget -O "${VMAF_ARCHIVE}" "${VMAF_URL}"
        fi
        tar xf "${VMAF_ARCHIVE}"
    fi
}

copy_vmaf_source() {
    local dst_dir="$1"

    rm -rf "${dst_dir}"
    if [ -d "${LOCAL_VMAF_SRC}/libvmaf" ]; then
        cp -a "${LOCAL_VMAF_SRC}" "${dst_dir}"
    else
        find "${SRC_DIR}" -maxdepth 1 -type d -name "vmaf-*" | head -n 1 | xargs -I{} cp -a "{}" "${dst_dir}"
    fi
}

maybe_archive_sources() {
    if [ "${SKIP_SRC_ARCHIVE}" = "TRUE" ]; then
        return 0
    fi
    if ! command -v 7z >/dev/null 2>&1; then
        return 0
    fi
    cd "${SRC_DIR}"
    rm -f vmaf_src.7z
    echo "compressing src file..."
    7z a -y -t7z -mx=9 -myx=9 -mmt=off \
        -x\!'*.tar.gz' -x\!'*.tar.bz2' -x\!'*.zip' -x\!'*.tar.xz' \
        -xr\!'.git' -xr\!'doc' -xr\!'docs' \
        vmaf_src.7z "${SRC_DIR}"/vmaf*/libvmaf > /dev/null
}

prepare_vmaf_source

mkdir -p "${BUILD_DIR}/${TARGET_ARCH}"
copy_vmaf_source "${BUILD_DIR}/${TARGET_ARCH}/vmaf"

cd "${BUILD_DIR}/${TARGET_ARCH}/vmaf/libvmaf"
rm -rf build

MESON_COMMON_ARGS=(
    "build"
    "--backend=ninja"
    "--buildtype=release"
    "--prefix=${INSTALL_DIR}"
    "--libdir=lib"
    "-Denable_tests=false"
    "-Denable_docs=false"
    "-Denable_tools=false"
)

if [ "${BUILD_MODE}" = "shared" ]; then
    MESON_LIBRARY_ARG="--default-library=shared"
else
    MESON_LIBRARY_ARG="--default-library=static"
fi

CC=gcc \
CXX=g++ \
PKG_CONFIG_PATH="${PKG_CONFIG_DIR}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}" \
CFLAGS="${BUILD_CCFLAGS}" \
CPPFLAGS="${BUILD_CCFLAGS}" \
LDFLAGS="${BUILD_LDFLAGS}" \
meson setup "${MESON_COMMON_ARGS[@]}" "${MESON_LIBRARY_ARG}"

ninja -vC build install

if [ "${BUILD_MODE}" = "shared" ]; then
    cd "${INSTALL_DIR}/bin"
    gendef libvmaf.dll
    LIBVMAF_LIB_FILENAME=libvmaf.lib
    LIBVMAF_DEF_FILENAME=libvmaf.def
    lib.exe -machine:${TARGET_ARCH} -def:${LIBVMAF_DEF_FILENAME} -out:${LIBVMAF_LIB_FILENAME}
else
    rm -f "${INSTALL_DIR}/lib"/libvmaf.so*
fi

maybe_archive_sources
