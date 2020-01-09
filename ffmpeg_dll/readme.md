#### Install tools required to Windows
- Visual Studio 2019
- Cmake (64bit)
- MSYS2

#### Update msys2
```
pacman -Syuu
```

#### Install tools required to MSYS2
```
pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain p7zip git nasm python unzip
pacman -S mingw32/mingw-w64-i686-meson mingw64/mingw-w64-x86_64-meson
pacman -S mingw32/mingw-w64-i686-python-lxml mingw64/mingw-w64-x86_64-python-lxml
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