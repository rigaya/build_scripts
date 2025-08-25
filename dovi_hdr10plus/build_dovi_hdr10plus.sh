#!/bin/bash
#dovi.lib,hdr10plus-rs.libビルドスクリプト(MSVC向け/MT静的リンク用ライブラリ)
#Visual Studioへの環境変数を通して起動する
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


BUILD_DIR=$HOME/build_dovi

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
if [ ! -d "dovi_tool-2.3.1" ]; then
    wget -O dovi_tool-2.3.1.tar.gz https://github.com/quietvoid/dovi_tool/archive/refs/tags/2.3.1.tar.gz
    tar xf dovi_tool-2.3.1.tar.gz
fi

if [ ! -d "hdr10plus_tool-1.7.1" ]; then
    wget -O hdr10plus_tool-1.7.1.tar.gz https://github.com/quietvoid/hdr10plus_tool/archive/refs/tags/1.7.1.tar.gz
    tar xf hdr10plus_tool-1.7.1.tar.gz
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
    cargo cinstall --target ${FFMPEG_ARCH}-pc-windows-msvc --release --prefix=msvc_${TARGET_ARCH}
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
    cargo cinstall --target ${FFMPEG_ARCH}-pc-windows-msvc --release --prefix=msvc_${TARGET_ARCH}
fi
