# libav*.dll build

Create libav*.dlls.

## Install tools required to Windows
- Visual Studio 2022
- [MSYS2](https://www.msys2.org/)

## Install rust on cmd

```bat
curl -o rustup-init.exe -sSL https://win.rustup.rs/
./rustup-init.exe -y --default-host=x86_64-pc-windows-gnu
rustup install stable --profile minimal
rustup default stable
rustup target add x86_64-pc-windows-gnu
rustup target add i686-pc-windows-gnu
```

## Install tools required on MSYS2
```sh
pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools autogen p7zip git nasm yasm python unzip gtk-doc gperf
pacman -S mingw32/mingw-w64-i686-cmake mingw64/mingw-w64-x86_64-cmake
pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson
pacman -S mingw32/mingw-w64-i686-python mingw64/mingw-w64-x86_64-python
pacman -S mingw32/mingw-w64-i686-python-lxml mingw64/mingw-w64-x86_64-python-lxml
pacman -S mingw32/mingw-w64-i686-python-six mingw64/mingw-w64-x86_64-python-six
pacman -S mingw32/mingw-w64-i686-ragel mingw64/mingw-w64-x86_64-ragel
pacman -S mingw32/mingw-w64-i686-uasm mingw64/mingw-w64-x86_64-uasm
```

Additional packages for libvmaf CUDA build on MSYS2 mingw64:

```sh
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-meson mingw-w64-x86_64-ninja nasm vim git
```

## Copy scripts to $HOME dir
```
$HOME
|- patches [directory]
|- build_ffmpeg_dll.sh
|- build_get_audlist.py
```

## Copy Launcher scripts and launch mingw32 / mingw64
Copy scripts below to the directory where mingw64.exe exists
- mingw32_vsvar.cmd
- mingw64_vsvar.cmd

Launch msys2 by mingw32_vsvar.cmd / mingw64_vsvar.cmd and the run build scipt.

This will launch with Visual Studio 2022 environment enabled.

## Install cargo-c on mingw32 / mingw64

### x64
```sh
rustup default stable-x86_64-pc-windows-gnu
cargo install --target x86_64-pc-windows-gnu cargo-c
```

### x86
```sh
rustup default stable-i686-pc-windows-gnu
cargo install --target i686-pc-windows-gnu cargo-c
```

## Run build on mingw32 / mingw64

### build dll for hwenc
```sh
./build_ffmpeg_dll.sh
```

### build standalone exe for ffmpegOut
```sh
./build_ffmpeg_dll.sh --target exe --enable-gpl --enable-swscale
```

## Build libvmaf

`build_libvmaf.sh` builds libvmaf 3.2.0 by default.

- On MSYS2 without CUDA, it builds the traditional MinGW `libvmaf.dll`.
- On MSYS2 mingw64 with CUDA enabled, it builds CUDA-enabled `libvmaf.dll` using MSVC + CUDA.
- On Linux/WSL2, it builds static-only `libvmaf.a`.
- On Linux/WSL2 with CUDA enabled, it builds CUDA-enabled static-only `libvmaf.a`.

### Build libvmaf with CUDA on Windows

Requirements:

- Visual Studio 2022 with C++ build tools and Windows SDK.
- CUDA Toolkit x64. `nvcc`, `bin2c`, and `include/cuda.h` must exist under `CUDA_PATH`.
- MSYS2 mingw64 shell. CUDA build is x64 only.
- MSYS2 packages listed above, especially `meson`, `ninja`, `nasm`, `vim` (`xxd`), `git`, and mingw64 GCC.

Run from MSYS2 mingw64:

```sh
cd build_scripts/ffmpeg_dll
./build_libvmaf.sh --enable-cuda
```

If Visual Studio or CUDA is installed in a non-default location, specify paths explicitly:

```sh
CUDA_PATH="/c/Program Files/NVIDIA GPU Computing Toolkit/CUDA/v12.8" \
VCVARS_BAT="/c/Program Files/Microsoft Visual Studio/2022/Community/VC/Auxiliary/Build/vcvars64.bat" \
./build_libvmaf.sh --enable-cuda
```

The script loads the MSVC environment through `vcvars64.bat`, keeps the MSYS2 mingw64 tools in `PATH`, and then runs Meson/Ninja with CUDA enabled. It also downloads `nv-codec-headers`, copies pthread headers needed by nvcc on Windows, enables built-in VMAF models, and links the MinGW runtime into `libvmaf.dll` by default.

Outputs:

```text
build_scripts/ffmpeg_dll/x64/build/bin/libvmaf.dll
build_scripts/ffmpeg_dll/x64/build/bin/libvmaf.lib
build_scripts/ffmpeg_dll/x64/build/include/libvmaf/libvmaf_cuda.h
```

Useful options and environment variables:

```sh
./build_libvmaf.sh --enable-cuda        # require CUDA; fail if CUDA cannot be used
./build_libvmaf.sh --disable-cuda       # force CPU-only build
./build_libvmaf.sh --skip-src-archive   # skip source archive creation

VMAF_VERSION=3.2.0                     # libvmaf version
CUDA_PATH=/c/ProgramAnother/CUDA/v12.9  # CUDA Toolkit path
VCVARS_BAT=/c/.../vcvars64.bat          # Visual Studio environment script
MINGW64_PREFIX=/mingw64                 # MSYS2 mingw64 prefix
MSYS2_USR_BIN=/usr/bin                  # xxd location
EMBED_MINGW_RUNTIME=1                   # statically link MinGW runtime into dll
AUTO_INSTALL_PACKAGES=1                 # install required MSYS2 packages with pacman
```

When CUDA mode is `auto` (the default), the script falls back to CPU-only build if a complete CUDA Toolkit is not found. Use `--enable-cuda` for release builds where CUDA support is required.
