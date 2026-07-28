#!/bin/bash
# libvmaf build script
# - MSYS2: build libvmaf.dll
# - MSYS2 + MSVC + CUDA: build CUDA-enabled libvmaf.dll
# - Linux/WSL2: build static-only libvmaf.a
# - Linux/WSL2 + GCC + CUDA: build CUDA-enabled static-only libvmaf.a

set -euo pipefail

SKIP_SRC_ARCHIVE="FALSE"
CUDA_MODE="${CUDA_MODE:-auto}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-src-archive)
            SKIP_SRC_ARCHIVE="TRUE"
            shift
            ;;
        --enable-cuda)
            CUDA_MODE="on"
            shift
            ;;
        --disable-cuda)
            CUDA_MODE="off"
            shift
            ;;
        --cuda-path=*)
            CUDA_PATH="${1#*=}"
            shift
            ;;
        --vcvars-bat=*)
            VCVARS_BAT="${1#*=}"
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [options]

Options:
  --enable-cuda        CUDA対応libvmafを必須にする
  --disable-cuda       従来のCPU向けlibvmafをビルドする
  --cuda-path=PATH     CUDA Toolkitのパスを指定する
  --vcvars-bat=PATH    Windows CUDAビルドで使うvcvars64.batを指定する
  --skip-src-archive   ソースアーカイブ作成を省略する
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
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
VMAF_VERSION="${VMAF_VERSION:-3.2.0}"
VMAF_ARCHIVE="v${VMAF_VERSION}.tar.gz"
VMAF_URL="https://github.com/Netflix/vmaf/archive/refs/tags/${VMAF_ARCHIVE}"
VMAF_SRC_STAMP_DIR="vmaf-${VMAF_VERSION}"
LOCAL_VMAF_SRC="${REPO_ROOT}/vmaf"
NV_CODEC_HEADERS_REPO="${NV_CODEC_HEADERS_REPO:-https://github.com/FFmpeg/nv-codec-headers.git}"
NV_CODEC_HEADERS_REF="${NV_CODEC_HEADERS_REF:-master}"
NV_CODEC_HEADERS_DIR="${NV_CODEC_HEADERS_DIR:-${WORK_DIR}/nv-codec-headers}"
BUILD_TYPE="${BUILD_TYPE:-release}"
BUILD_DIR_NAME="${BUILD_DIR_NAME:-build}"
AUTO_INSTALL_PACKAGES="${AUTO_INSTALL_PACKAGES:-0}"
MINGW64_PREFIX="${MINGW64_PREFIX:-/mingw64}"
MSYS2_USR_BIN="${MSYS2_USR_BIN:-/usr/bin}"
EMBED_MINGW_RUNTIME="${EMBED_MINGW_RUNTIME:-1}"
VCVARS_BAT="${VCVARS_BAT:-/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat}"
CUDA_PATH="${CUDA_PATH:-}"
NVCC_PREPEND_FLAGS="${NVCC_PREPEND_FLAGS:--allow-unsupported-compiler -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH}"

mkdir -p "${BUILD_DIR}"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

IS_MSYS="FALSE"
if [ "${MSYSTEM:-}" = "MINGW32" ]; then
    IS_MSYS="TRUE"
    TARGET_ARCH="x86"
    BUILD_MODE="shared"
    MINGWDIR="mingw32"
elif [ "${MSYSTEM:-}" = "MINGW64" ] || [ "${MSYSTEM:-}" = "UCRT64" ] || [ "${MSYSTEM:-}" = "CLANG64" ]; then
    IS_MSYS="TRUE"
    TARGET_ARCH="x64"
    BUILD_MODE="shared"
    MINGWDIR="${MSYSTEM,,}"
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
VMAF_COPY_DIR="${BUILD_DIR}/${TARGET_ARCH}/vmaf"
LIBVMAF_DIR="${VMAF_COPY_DIR}/libvmaf"

log() { printf '[build-libvmaf] %s\n' "$*"; }
die() { log "ERROR: $*"; exit 1; }

to_mixed_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

convert_win_path_list() {
    local win_list="$1" result="" part
    local old_ifs="$IFS"
    IFS=';'
    for part in $win_list; do
        [ -n "$part" ] || continue
        result+="$(cygpath -u "$part"):"
    done
    IFS="$old_ifs"
    echo "${result%:}"
}

find_cuda_path() {
    if [ -n "${CUDA_PATH}" ] && [ -d "${CUDA_PATH}" ]; then
        return 0
    fi
    if [ "${IS_MSYS}" = "TRUE" ]; then
        for candidate in /c/ProgramAnother/CUDA/v12.9 /c/ProgramAnother/CUDA/v12.8 /c/ProgramAnother/CUDA/v12.4 /c/ProgramAnother/CUDA/v11.8 /c/Program\ Files/NVIDIA\ GPU\ Computing\ Toolkit/CUDA/v12.9 /c/Program\ Files/NVIDIA\ GPU\ Computing\ Toolkit/CUDA/v12.8 /c/Program\ Files/NVIDIA\ GPU\ Computing\ Toolkit/CUDA/v12.4 /c/Program\ Files/NVIDIA\ GPU\ Computing\ Toolkit/CUDA/v11.8; do
            if [ -d "$candidate" ]; then
                CUDA_PATH="$candidate"
                return 0
            fi
        done
    else
        for candidate in /usr/local/cuda /opt/cuda; do
            if [ -d "$candidate" ]; then
                CUDA_PATH="$candidate"
                return 0
            fi
        done
        if command -v nvcc >/dev/null 2>&1; then
            CUDA_PATH="$(cd "$(dirname "$(dirname "$(command -v nvcc)")")" && pwd)"
            return 0
        fi
    fi
    return 1
}

cuda_toolkit_complete() {
    [ -n "${CUDA_PATH}" ] || return 1
    [ -d "${CUDA_PATH}" ] || return 1
    [ -f "${CUDA_PATH}/include/cuda.h" ] || return 1
    { [ -x "${CUDA_PATH}/bin/nvcc" ] || [ -x "${CUDA_PATH}/bin/nvcc.exe" ] || command -v nvcc >/dev/null 2>&1; } || return 1
    { [ -x "${CUDA_PATH}/bin/bin2c" ] || [ -x "${CUDA_PATH}/bin/bin2c.exe" ] || command -v bin2c >/dev/null 2>&1; } || return 1
    return 0
}

resolve_cuda_mode() {
    ENABLE_CUDA="FALSE"
    if [ "${CUDA_MODE}" = "off" ]; then
        return 0
    fi
    if [ "${TARGET_ARCH}" != "x64" ]; then
        if [ "${CUDA_MODE}" = "on" ]; then
            die "CUDAビルドはx64のみ対応です: TARGET_ARCH=${TARGET_ARCH}"
        fi
        return 0
    fi
    if find_cuda_path; then
        if cuda_toolkit_complete; then
            ENABLE_CUDA="TRUE"
        elif [ "${CUDA_MODE}" = "on" ]; then
            die "CUDA Toolkitが不完全です: CUDA_PATH=${CUDA_PATH} (nvcc/bin2c/cuda.hを確認してください)"
        else
            log "CUDA Toolkitが不完全なためCPUビルドへフォールバックします: CUDA_PATH=${CUDA_PATH}"
        fi
    elif [ "${CUDA_MODE}" = "on" ]; then
        die "CUDA Toolkitが見つかりません。--cuda-path=PATH または CUDA_PATH を指定してください。"
    fi
}

install_packages_if_needed() {
    [ "${IS_MSYS}" = "TRUE" ] || return 0
    [ "${AUTO_INSTALL_PACKAGES}" = "1" ] || return 0
    command -v pacman >/dev/null 2>&1 || {
        log "pacmanが見つからないためAUTO_INSTALL_PACKAGESをスキップします。"
        return 0
    }
    pacman -S --needed --noconfirm \
        mingw-w64-x86_64-gcc \
        mingw-w64-x86_64-meson \
        mingw-w64-x86_64-ninja \
        nasm \
        vim
}

load_msvc_env() {
    [ "${ENABLE_CUDA}" = "TRUE" ] || return 0
    [ "${IS_MSYS}" = "TRUE" ] || return 0

    [ -f "${VCVARS_BAT}" ] || die "vcvars64.batが見つかりません: ${VCVARS_BAT}"
    [ -d "${MINGW64_PREFIX}" ] || die "MINGW64_PREFIXが見つかりません: ${MINGW64_PREFIX}"
    [ -d "${CUDA_PATH}" ] || die "CUDA_PATHが見つかりません: ${CUDA_PATH}"

    local vcvars_win batch
    vcvars_win="$(cygpath -w "${VCVARS_BAT}")"
    batch="$(mktemp "${TMPDIR:-/tmp}/vcvars_export.XXXXXX.bat")"
    cat > "${batch}" <<EOF
@echo off
call "${vcvars_win}" >nul
set
EOF

    local msvc_path=""
    while IFS= read -r line; do
        line="${line%$'\r'}"
        case "${line}" in
            INCLUDE=*|LIB=*|LIBPATH=*|VCINSTALLDIR=*|VCToolsInstallDir=*|WindowsSdkDir=*|WindowsSDKVersion=*|UniversalCRTSdkDir=*)
                export "${line}"
                ;;
            PATH=*)
                msvc_path="${line#PATH=}"
                ;;
        esac
    done < <(cmd.exe //c "$(cygpath -w "${batch}")" 2>/dev/null)
    rm -f "${batch}"

    [ -n "${msvc_path}" ] || die "MSVC環境の読み込みに失敗しました: ${VCVARS_BAT}"

    local msvc_path_unix
    msvc_path_unix="$(convert_win_path_list "${msvc_path}")"
    export PATH="${MSYS2_USR_BIN}:${MINGW64_PREFIX}/bin:${CUDA_PATH}/bin:${msvc_path_unix}"
    export CUDA_PATH

    command -v cl.exe >/dev/null 2>&1 || die "cl.exeが見つかりません。"
    command -v nvcc >/dev/null 2>&1 || die "nvccが見つかりません: CUDA_PATH=${CUDA_PATH}"
    [ -f "${CUDA_PATH}/include/cuda.h" ] || die "cuda.hが見つかりません: ${CUDA_PATH}/include/cuda.h"
    command -v bin2c >/dev/null 2>&1 || die "bin2cが見つかりません: ${CUDA_PATH}/bin"
    command -v gcc >/dev/null 2>&1 || die "gccが見つかりません: ${MINGW64_PREFIX}/bin"
    command -v xxd >/dev/null 2>&1 || die "xxdが見つかりません。MSYS2では pacman -S vim を実行してください。"

    log "MSVC: $(cl.exe 2>&1 | sed -n '1p')"
    log "CUDA: $(nvcc --version | sed -n '1p')"
}

prepare_cuda_env_linux() {
    [ "${ENABLE_CUDA}" = "TRUE" ] || return 0
    [ "${IS_MSYS}" = "FALSE" ] || return 0

    [ -d "${CUDA_PATH}" ] || die "CUDA_PATHが見つかりません: ${CUDA_PATH}"
    export CUDA_PATH
    export PATH="${CUDA_PATH}/bin:${PATH}"

    command -v nvcc >/dev/null 2>&1 || die "nvccが見つかりません: CUDA_PATH=${CUDA_PATH}"
    [ -f "${CUDA_PATH}/include/cuda.h" ] || die "cuda.hが見つかりません: ${CUDA_PATH}/include/cuda.h"
    command -v bin2c >/dev/null 2>&1 || die "bin2cが見つかりません: ${CUDA_PATH}/bin"
    command -v xxd >/dev/null 2>&1 || die "xxdが見つかりません。built-in models生成に必要です。"

    log "CUDA: $(nvcc --version | sed -n '1p')"
}

prepare_vmaf_source() {
    if [ -d "${LOCAL_VMAF_SRC}/libvmaf" ]; then
        log "Using local source: ${LOCAL_VMAF_SRC}"
        return 0
    fi
    if source_version_matches "${VMAF_COPY_DIR}"; then
        log "Using existing build source: ${VMAF_COPY_DIR}"
        return 0
    fi

    if [ ! -d "${VMAF_SRC_STAMP_DIR}" ]; then
        if [ ! -f "${VMAF_ARCHIVE}" ]; then
            wget -O "${VMAF_ARCHIVE}" "${VMAF_URL}"
        fi
        tar xf "${VMAF_ARCHIVE}"
    fi
}

source_version() {
    local src_root="$1"
    if [ -f "${src_root}/libvmaf/meson.build" ]; then
        sed -n "s/.*version[[:space:]]*:[[:space:]]*'\([^']*\)'.*/\1/p" "${src_root}/libvmaf/meson.build" | head -n 1
    fi
}

source_version_matches() {
    local src_root="$1"
    local ver
    ver="$(source_version "${src_root}")"
    [ -n "${ver}" ] && [ "${ver}" = "${VMAF_VERSION}" ]
}

copy_vmaf_source() {
    local dst_dir="$1"

    if [ -d "${LOCAL_VMAF_SRC}/libvmaf" ]; then
        rm -rf "${dst_dir}"
        cp -a "${LOCAL_VMAF_SRC}" "${dst_dir}"
    elif [ -d "${SRC_DIR}/${VMAF_SRC_STAMP_DIR}/libvmaf" ]; then
        rm -rf "${dst_dir}"
        cp -a "${SRC_DIR}/${VMAF_SRC_STAMP_DIR}" "${dst_dir}"
    elif source_version_matches "${dst_dir}"; then
        log "Reusing existing source tree: ${dst_dir}"
    else
        die "vmaf ${VMAF_VERSION} sourceが見つかりません: ${SRC_DIR} または ${LOCAL_VMAF_SRC}"
    fi
}

prepare_nv_codec_headers() {
    [ "${ENABLE_CUDA}" = "TRUE" ] || return 0

    if [ ! -d "${NV_CODEC_HEADERS_DIR}/include/ffnvcodec" ]; then
        log "cloning nv-codec-headers -> ${NV_CODEC_HEADERS_DIR}"
        rm -rf "${NV_CODEC_HEADERS_DIR}"
        git clone --depth 1 --branch "${NV_CODEC_HEADERS_REF}" "${NV_CODEC_HEADERS_REPO}" "${NV_CODEC_HEADERS_DIR}"
    fi

    [ -d "${NV_CODEC_HEADERS_DIR}/include/ffnvcodec" ] || die "ffnvcodec headersが見つかりません: ${NV_CODEC_HEADERS_DIR}"
    rm -rf "${LIBVMAF_DIR}/src/ffnvcodec"
    cp -r "${NV_CODEC_HEADERS_DIR}/include/ffnvcodec" "${LIBVMAF_DIR}/src/"
}

apply_windows_cuda_patches() {
    [ "${ENABLE_CUDA}" = "TRUE" ] || return 0
    [ "${IS_MSYS}" = "TRUE" ] || return 0

    local cuda_dir="${LIBVMAF_DIR}/src/cuda"
    local adm_h="${LIBVMAF_DIR}/src/feature/integer_adm.h"
    local pthread_headers=(
        pthread.h
        pthread_compat.h
        pthread_signal.h
        pthread_time.h
        pthread_unistd.h
        sched.h
    )

    log "Windows/CUDA向けパッチを適用します。"
    for h in "${pthread_headers[@]}"; do
        [ -f "${MINGW64_PREFIX}/include/${h}" ] || die "missing ${MINGW64_PREFIX}/include/${h}"
        cp -f "${MINGW64_PREFIX}/include/${h}" "${cuda_dir}/"
    done

    sed -i 's/#include <pthread.h>/#include "pthread.h"/g' \
        "${cuda_dir}/common.h" \
        "${cuda_dir}/ring_buffer.c"

    if grep -q '{.a = 0.495' "${adm_h}"; then
        sed -i \
            -e 's/{\.a = 0\.495, \.k = 0\.466, \.f0 = 0\.401, \.g = {1\.501, 1\.0, 0\.534, 1\.0}}/{0.495, 0.466, 0.401, {1.501, 1.0, 0.534, 1.0}}/' \
            -e 's/{\.a = 1\.633, \.k = 0\.353, \.f0 = 0\.209, \.g = {1\.520, 1\.0, 0\.502, 1\.0}}/{1.633, 0.353, 0.209, {1.520, 1.0, 0.502, 1.0}}/' \
            -e 's/{\.a = 0\.944, \.k = 0\.521, \.f0 = 0\.404, \.g = {1\.868, 1\.0, 0\.516, 1\.0}}/{0.944, 0.521, 0.404, {1.868, 1.0, 0.516, 1.0}}/' \
            "${adm_h}"
    fi
}

apply_cuda_arch_patches() {
    [ "${ENABLE_CUDA}" = "TRUE" ] || return 0

    local meson_file="${LIBVMAF_DIR}/src/meson.build"
    [ -f "${meson_file}" ] || die "libvmafのMeson定義が見つかりません: ${meson_file}"
    if grep -q "compute_89,code=\[compute_89,sm_89\]" "${meson_file}"; then
        return 0
    fi

    log "CUDA 11.8向けにlibvmafのfatbin生成対象を拡張します。"
    (
        cd "${LIBVMAF_DIR}"
        patch --batch --forward -p1 <<'PATCH'
diff --git a/src/meson.build b/src/meson.build
--- a/src/meson.build
+++ b/src/meson.build
@@ -367,27 +367,37 @@ if is_cuda_enabled
         cuda_compiler = meson.get_compiler('cuda')
         nvcc_exe = find_program('nvcc')
 
-        gencode = [
-            '--fatbin',
-            '-gencode=arch=compute_75,code=sm_75',
-            '-gencode=arch=compute_80,code=sm_80',
-        ]
+        gencode = [ '--fatbin' ]
         message('Found CUDA version = @0@'.format(cuda_compiler.version()))
-        if cuda_compiler.version().version_compare('<13')
-            gencode += '-gencode=arch=compute_50,code=compute_50'
-        endif
-        # always compile device code to enable quick startup on newer GPUs, for the last supported GPU also generate PTX for future compatibility
-        if cuda_compiler.version().version_compare('>11.8')
-            gencode += '-gencode=arch=compute_90,code=sm_90'
-            if cuda_compiler.version().version_compare('>12.8')
-                gencode += [
-                    '-gencode=arch=compute_100,code=sm_100',
-                    '-gencode=arch=compute_120,code=sm_120',
-                    '-gencode=arch=compute_120,code=compute_120'
-                ]
+        if cuda_compiler.version().version_compare('>=11.8') and cuda_compiler.version().version_compare('<12')
+            gencode += [
+                '-gencode=arch=compute_50,code=[compute_50,sm_50]',
+                '-gencode=arch=compute_61,code=[compute_61,sm_61]',
+                '-gencode=arch=compute_75,code=[compute_75,sm_75]',
+                '-gencode=arch=compute_86,code=[compute_86,sm_86]',
+                '-gencode=arch=compute_89,code=[compute_89,sm_89]',
+            ]
+        else
+            gencode += [
+                '-gencode=arch=compute_75,code=sm_75',
+                '-gencode=arch=compute_80,code=sm_80',
+            ]
+            if cuda_compiler.version().version_compare('<13')
+                gencode += '-gencode=arch=compute_50,code=compute_50'
+            endif
+            # always compile device code to enable quick startup on newer GPUs, for the last supported GPU also generate PTX for future compatibility
+            if cuda_compiler.version().version_compare('>11.8')
+                gencode += '-gencode=arch=compute_90,code=sm_90'
+                if cuda_compiler.version().version_compare('>12.8')
+                    gencode += [
+                        '-gencode=arch=compute_100,code=sm_100',
+                        '-gencode=arch=compute_120,code=sm_120',
+                        '-gencode=arch=compute_120,code=compute_120'
+                    ]
+                else
+                    gencode += '-gencode=arch=compute_90,code=compute_90'
+                endif
             else
-                gencode += '-gencode=arch=compute_90,code=compute_90'
+                gencode += '-gencode=arch=compute_80,code=compute_80'
             endif
-        else
-            gencode += '-gencode=arch=compute_80,code=compute_80'
         endif
 
     else
PATCH
    )
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

write_windows_cuda_native_file() {
    [ "${ENABLE_CUDA}" = "TRUE" ] || return 0
    [ "${IS_MSYS}" = "TRUE" ] || return 0

    local ini="${LIBVMAF_DIR}/meson_native_cuda_win.ini"
    local src_mixed
    src_mixed="$(to_mixed_path "${LIBVMAF_DIR}/src")"

    local cuda_args="''"
    if [ -n "${NVCC_PREPEND_FLAGS}" ]; then
        local args_list="" flag
        for flag in ${NVCC_PREPEND_FLAGS}; do
            args_list+="'${flag}', "
        done
        args_list="${args_list%, }"
        cuda_args="[${args_list}]"
    fi

    cat > "${ini}" <<EOF
[cuda]
args = ${cuda_args}

[built-in options]
c_args = ['-I${src_mixed}']
cpp_args = ['-I${src_mixed}']$( [ "${EMBED_MINGW_RUNTIME}" = "1" ] && printf "\nc_link_args = ['-static-libgcc', '-Wl,-Bstatic', '-lwinpthread', '-Wl,-Bdynamic']\ncpp_link_args = ['-static-libgcc', '-static-libstdc++', '-Wl,-Bstatic', '-lwinpthread', '-Wl,-Bdynamic']" )
EOF
}

setup_build_flags() {
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
    if [ "${ENABLE_CUDA}" = "TRUE" ]; then
        BUILD_CCFLAGS="${BUILD_CCFLAGS} -I${LIBVMAF_DIR}/src"
        if [ "${IS_MSYS}" = "TRUE" ]; then
            BUILD_CCFLAGS="${BUILD_CCFLAGS} -I$(to_mixed_path "${LIBVMAF_DIR}/src")"
        fi
    fi
}

build_libvmaf() {
    cd "${LIBVMAF_DIR}"
    rm -rf "${BUILD_DIR_NAME}"

    local meson_library_arg
    if [ "${ENABLE_CUDA}" = "TRUE" ] && [ "${IS_MSYS}" = "TRUE" ]; then
        meson_library_arg="--default-library=both"
    elif [ "${BUILD_MODE}" = "shared" ]; then
        meson_library_arg="--default-library=shared"
    else
        meson_library_arg="--default-library=static"
    fi

    MESON_COMMON_ARGS=(
        "${BUILD_DIR_NAME}"
        "--backend=ninja"
        "--buildtype=${BUILD_TYPE}"
        "--prefix=${INSTALL_DIR}"
        "--libdir=lib"
        "-Denable_tests=false"
        "-Denable_docs=false"
        "-Denable_tools=false"
        "-Dbuilt_in_models=true"
        "-Denable_float=true"
    )

    if [ "${ENABLE_CUDA}" = "TRUE" ]; then
        MESON_COMMON_ARGS+=("-Denable_cuda=true")
    else
        MESON_COMMON_ARGS+=("-Denable_cuda=false")
    fi
    if [ "${ENABLE_CUDA}" = "TRUE" ] && [ "${IS_MSYS}" = "TRUE" ]; then
        MESON_COMMON_ARGS+=("--native-file" "meson_native_cuda_win.ini")
    fi

    export CC=gcc
    export CXX=g++
    export PKG_CONFIG_PATH="${PKG_CONFIG_DIR}${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
    export CFLAGS="${BUILD_CCFLAGS}"
    export CPPFLAGS="${BUILD_CCFLAGS}"
    export CXXFLAGS="${BUILD_CCFLAGS}"
    export LDFLAGS="${BUILD_LDFLAGS}"
    if [ "${ENABLE_CUDA}" = "TRUE" ] && [ -n "${NVCC_PREPEND_FLAGS}" ]; then
        export NVCC_PREPEND_FLAGS
    else
        unset NVCC_PREPEND_FLAGS || true
    fi

    meson setup "${MESON_COMMON_ARGS[@]}" "${meson_library_arg}"
    ninja -j "${NJOBS}" -vC "${BUILD_DIR_NAME}" install
}

create_windows_import_lib() {
    [ "${BUILD_MODE}" = "shared" ] || return 0
    [ -f "${INSTALL_DIR}/bin/libvmaf.dll" ] || return 0

    cd "${INSTALL_DIR}/bin"
    if command -v gendef >/dev/null 2>&1 && command -v lib.exe >/dev/null 2>&1; then
        gendef libvmaf.dll
        lib.exe -machine:${TARGET_ARCH} -def:libvmaf.def -out:libvmaf.lib
    fi
}

cleanup_non_target_libraries() {
    if [ "${BUILD_MODE}" = "static" ]; then
        rm -f "${INSTALL_DIR}/lib"/libvmaf.so*
        rm -f "${INSTALL_DIR}/bin"/libvmaf.dll
    fi
}

print_results() {
    log "TARGET_ARCH=${TARGET_ARCH}"
    log "BUILD_MODE=${BUILD_MODE}"
    log "ENABLE_CUDA=${ENABLE_CUDA}"
    if [ "${ENABLE_CUDA}" = "TRUE" ]; then
        log "CUDA_PATH=${CUDA_PATH}"
    fi
    log "SRC_DIR=${SRC_DIR}"
    log "INSTALL_DIR=${INSTALL_DIR}"

    if grep -q 'VMAF_BUILT_IN_MODELS 1' "${LIBVMAF_DIR}/${BUILD_DIR_NAME}/src/config.h" 2>/dev/null; then
        log "built-in models: enabled"
    else
        log "WARNING: built-in models may be missing. xxdを確認してください。"
    fi
    if grep -q 'HAVE_CUDA 1' "${LIBVMAF_DIR}/${BUILD_DIR_NAME}/src/config.h" 2>/dev/null; then
        log "CUDA support: enabled"
    else
        log "CUDA support: disabled"
    fi
}

resolve_cuda_mode
install_packages_if_needed
load_msvc_env
prepare_cuda_env_linux

log "TARGET_ARCH=${TARGET_ARCH}"
log "BUILD_MODE=${BUILD_MODE}"
log "CUDA_MODE=${CUDA_MODE}"
log "ENABLE_CUDA=${ENABLE_CUDA}"
log "SRC_DIR=${SRC_DIR}"
log "INSTALL_DIR=${INSTALL_DIR}"

prepare_vmaf_source
mkdir -p "${BUILD_DIR}/${TARGET_ARCH}"
copy_vmaf_source "${VMAF_COPY_DIR}"
prepare_nv_codec_headers
apply_windows_cuda_patches
apply_cuda_arch_patches
write_windows_cuda_native_file
setup_build_flags
build_libvmaf
create_windows_import_lib
cleanup_non_target_libraries
maybe_archive_sources
print_results
