# Build by MSYS2

Create dovi.lib, hdr10plus-rs.lib for MSVC static link (/MT).

## Install tools
- Visual Studio 2022
- [MSYS2](https://www.msys2.org/)

## Install rust on cmd

```bat
curl -o rustup-init.exe -sSL https://win.rustup.rs/
./rustup-init.exe -y --default-host=x86_64-pc-windows-msvc
rustup install stable --profile minimal
rustup default stable
rustup target add x86_64-pc-windows-msvc
rustup target add i686-pc-windows-msvc
```

## Update msys2
```sh
pacman -Syuu
```

#### Copy Launcher scripts and launch mingw32 / mingw64
Copy scripts below to the directory where mingw64.exe exists
- mingw32_vsvar.cmd
- mingw64_vsvar.cmd

Launch msys2 by mingw32_vsvar.cmd / mingw64_vsvar.cmd and the run build scipt.

This will launch with Visual Studio 2022 environment enabled.

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