# Build by MSYS2

Create dovi.lib, hdr10plus-rs.lib for MSVC static link (/MT).

## Install tools
- MSYS2

## Install rust

```bat
curl -o rustup-init.exe -sSL https://win.rustup.rs/
./rustup-init.exe -y --default-host=x86_64-pc-windows-msvc
rustup install stable --profile minimal
rustup default stable
rustup target add x86_64-pc-windows-msvc
rustup target add i686-pc-windows-msvc
```

## Update msys2
```
pacman -Syuu
```

## Run mingw64 / mingw32 with Visual Studio environment

### x64

```bat
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
call "%VS170COMNTOOLS%\..\..\VC\Auxiliary\Build\vcvarsall.bat" x64

"%~dp0msys2_shell.cmd" -mingw64 -use-full-path
```

### x86

```bat
call "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
call "%VS170COMNTOOLS%\..\..\VC\Auxiliary\Build\vcvarsall.bat" x86

"%~dp0msys2_shell.cmd" -mingw32 -use-full-path
```

## Install cargo-c on mingw64 / mingw32

### x64

```sh
cargo install --target x86_64-pc-windows-msvc cargo-c
```

### x86

```sh
cargo install --target i686-pc-windows-msvc cargo-c
```

## Copy scripts to $HOME dir
```
$HOME
|- build_dovi_hdr10plus.sh
```

## Run build
```sh
./build_dovi_hdr10plus.sh
```