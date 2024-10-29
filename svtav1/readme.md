# Build by Visual Studio
## Install tools
- Visual Studio 2019
- Cmake (64bit)

## Copy scripts required
- Build_svtav1.bat
- Build_svtav1.props
- build_svtav1_forceAVX512.diff

## Change path in bat file
- TMP_PATH
- YUVFILE
- YUVFILE_10

## build
```
Build_svtav1.bat
```

# Build by MSYS2

## Install tools
- MSYS2

## Update msys2
```
pacman -Syuu
```

## Install tools required to MSYS2
```
pacman -S base-devel mingw-w64-clang-x86_64-toolchain clang64/mingw-w64-clang-x86_64-cmake p7zip git nasm
```

## Copy scripts to $HOME dir
```
$HOME
|- build_svtav1.sh
```

## Change path in bat file
- YUVFILE
- YUVFILE_10

## Run build
```
build_svtav1.sh
```