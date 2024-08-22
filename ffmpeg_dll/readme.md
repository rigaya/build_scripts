#### Install tools required to Windows
- Visual Studio 2019
- [MSYS2 20230526](https://repo.msys2.org/distrib/x86_64/msys2-x86_64-20230526.exe)

> [!IMPORTANT]
> Please do not update (```pacman -Syy```), to ensure to use gcc13. (gcc14 somehow creates failing binary)

#### Install tools required to MSYS2
```
pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools autogen p7zip git nasm yasm python unzip gtk-doc gperf
pacman -S mingw32/mingw-w64-i686-cmake mingw64/mingw-w64-x86_64-cmake
pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson
pacman -S mingw32/mingw-w64-i686-python-lxml mingw64/mingw-w64-x86_64-python-lxml
pacman -S mingw32/mingw-w64-i686-ragel mingw64/mingw-w64-x86_64-ragel
```

#### Copy scripts to $HOME dir
```
$HOME
|- patches [directory]
|- build_ffmpeg_dll.sh
|- build_get_audlist.py
```

#### Copy Launcher scripts
Copy scripts below to the directory where mingw64.exe exists
- mingw32_vsvar.cmd
- mingw64_vsvar.cmd

#### Run build
Launch msys2(64bit) by mingw64_vsvar.cmd and the run build scipt
```
build_ffmpeg_dll.sh -au
```