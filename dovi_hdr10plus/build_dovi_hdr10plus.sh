#!/bin/bash
#MSYS2用ffmpeg dllビルドスクリプト
# dovi / hdr10plus-rs の DLL は絶対に作らないこと（MSVC /MT 静的リンク用 .lib のみ）
# 下記インストールでgcc13系を持つmsys2を導入する (updateしてgcc14にしないこと、なぜか動作しないバイナリができる)
# https://repo.msys2.org/distrib/x86_64/msys2-x86_64-20230526.exe
#Visual Studioへの環境変数を通して起動する
#pacman -S base-devel mingw-w64-i686-toolchain mingw-w64-x86_64-toolchain autotools autogen
#pacman -S p7zip git nasm yasm python unzip
#libdoviに必要
# curl -o rustup-init.exe -sSL https://win.rustup.rs/
# ./rustup-init.exe -y --default-host=x86_64-pc-windows-gnu
# rustup install stable --profile minimal
# rustup default stable
# rustup target add x86_64-pc-windows-gnu
# rustup target add x86_64-pc-windows-msvc
# rustup target add i686-pc-windows-gnu
# rustup target add i686-pc-windows-msvc
# デフォルトをgnuのほうにしておかないとlinkエラーが出る
# rustup default stable-x86_64-pc-windows-msvc
# cargo install cargo-c
NJOBS=$NUMBER_OF_PROCESSORS
UPDATE_CARGO=0


BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/build_dovi"

mkdir -p $BUILD_DIR
mkdir -p $BUILD_DIR/src
cd $BUILD_DIR/src

# [ "x86", "x64" ]
if [ $MSYSTEM = "MINGW32" ]; then
    TARGET_ARCH="x86"
    VC_ARCH="win32"
    FFMPEG_ARCH="i686"
    MINGWDIR="mingw32"
else
    TARGET_ARCH="x64"
    VC_ARCH="x64"
    FFMPEG_ARCH="x86_64"
    MINGWDIR="mingw64"
fi

INSTALL_DIR=$BUILD_DIR/$TARGET_ARCH/build

echo TARGET_ARCH=$TARGET_ARCH
echo UPDATE_CARGO=$UPDATE_CARGO

if [ $UPDATE_CARGO != 0 ]; then
    rustup target add ${FFMPEG_ARCH}-pc-windows-msvc
    cargo install --target ${FFMPEG_ARCH}-pc-windows-msvc cargo-c
fi

#--- ソースのダウンロード ---------------------------------------
if [ ! -d "dovi_tool-2.3.3" ]; then
    curl -L -o dovi_tool-2.3.3.tar.gz https://github.com/quietvoid/dovi_tool/archive/refs/tags/2.3.3.tar.gz
    tar xf dovi_tool-2.3.3.tar.gz
fi

if [ ! -d "hdr10plus_tool-1.7.2" ]; then
    curl -L -o hdr10plus_tool-1.7.2.tar.gz https://github.com/quietvoid/hdr10plus_tool/archive/refs/tags/1.7.2.tar.gz
    tar xf hdr10plus_tool-1.7.2.tar.gz
fi

# --- 出力先を準備 --------------------------------------
rm -rf $BUILD_DIR/$TARGET_ARCH
mkdir $BUILD_DIR/$TARGET_ARCH

# --- ビルド開始 対象のフォルダがなければビルドを行う -----------
cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "dovi_tool" ]; then
    find ../src/ -type d -name "dovi_tool-*" | xargs -i cp -r {} ./dovi_tool
    cd ./dovi_tool/dolby_vision
    mkdir -p .cargo
    cat > .cargo/config.toml << 'EOF'
# for MSVC 32bit
[target.i686-pc-windows-msvc]
rustflags = ["-C", "target-feature=+crt-static"]

# for MSVC 64bit
[target.x86_64-pc-windows-msvc]
rustflags = ["-C", "target-feature=+crt-static"]
EOF
    cargo cinstall --target ${FFMPEG_ARCH}-pc-windows-msvc --release --library-type staticlib --prefix=msvc_${TARGET_ARCH}
fi

cd $BUILD_DIR/$TARGET_ARCH
if [ ! -d "hdr10plus_tool" ]; then
    find ../src/ -type d -name "hdr10plus_tool-*" | xargs -i cp -r {} ./hdr10plus_tool
    mkdir -p .cargo
    cat > .cargo/config.toml << 'EOF'
# for MSVC 32bit
[target.i686-pc-windows-msvc]
rustflags = ["-C", "target-feature=+crt-static"]

# for MSVC 64bit
[target.x86_64-pc-windows-msvc]
rustflags = ["-C", "target-feature=+crt-static"]
EOF
    cd ./hdr10plus_tool/hdr10plus
    cargo cinstall --target ${FFMPEG_ARCH}-pc-windows-msvc --release --library-type staticlib --prefix=msvc_${TARGET_ARCH}
fi
