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