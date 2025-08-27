# Build by MSYS2

Create l-smash works plugins.

## Install tools
- [MSYS2](https://www.msys2.org/)

## Update msys2
```sh
pacman -Syuu
```

#### Install tools required on MSYS2
```sh
pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools autogen p7zip git nasm yasm unzip gtk-doc gperf
pacman -S mingw32/mingw-w64-i686-cmake mingw64/mingw-w64-x86_64-cmake
pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson
pacman -S mingw32/mingw-w64-i686-python mingw64/mingw-w64-x86_64-python
pacman -S mingw32/mingw-w64-i686-python-lxml mingw64/mingw-w64-x86_64-python-lxml
pacman -S mingw32/mingw-w64-i686-python-six mingw64/mingw-w64-x86_64-python-six
pacman -S mingw32/mingw-w64-i686-ragel mingw64/mingw-w64-x86_64-ragel
```

## Copy scripts to $HOME dir
```
$HOME
|- build_lsmashworks.sh
|- [patches]
```

## Run build
```sh
./build_lsmashworks.sh
```