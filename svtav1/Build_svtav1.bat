@echo off

set CMAKE_DIR=C:\Program Files\CMake\bin
set TMP_PATH=F:\temp\build_svtav1
set INSTALL_DIR=%TMP_PATH%\build
set SVTAV1_PATH=%TMP_PATH%\svt-av1
set SVTAV1_DIFF=C:\ProgramEx\build_svtav1_forceAVX512.diff
set BUILD_PROP_PATH=Build_svtav1.props
set YUVFILE=Y:\Encoders\sakura_op_1280x720.yuv
set YUVFILE_10=Y:\Encoders\sakura_10.yuv
set STATSFILE=%TMP_PATH%\profile.stats

set PATH=%CMAKE_DIR%;%PATH%

rd /s /q "%SVTAV1_PATH%"
git clone https://gitlab.com/AOMediaCodec/SVT-AV1.git "%SVTAV1_PATH%"

cd /d "%SVTAV1_PATH%"
git apply "%SVTAV1_DIFF%"

cd /d "%SVTAV1_PATH%\build"
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat" x64
cmake -A x64 ^
  -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
  -DCMAKE_CONFIGURATION_TYPES="Release" ^
  -DENABLE_AVX512=ON ^
  -DBUILD_SHARED_LIBS=OFF ^
  -DBUILD_TESTING=OFF ^
  ..


MSBuild svt-av1.sln /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="Release";Platform=x64;WholeProgramOptimization=PGInstrument;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%"

"%SVTAV1_PATH%\Bin\Release\SvtAv1EncApp.exe" -i "%YUVFILE%"    -w 1280 -h 720 -n 50 --rc 0 --qp 26 --fps 30 --preset 4 --irefresh-type 2
"%SVTAV1_PATH%\Bin\Release\SvtAv1EncApp.exe" -i "%YUVFILE_10%" -w 1280 -h 720 -n 50 --rc 0 --qp 26 --fps 30 --preset 4 --irefresh-type 2 --input-depth 10

"%SVTAV1_PATH%\Bin\Release\SvtAv1EncApp.exe" -i "%YUVFILE%"    -w 1280 -h 720 -n 50 --rc 0 --qp 26 --fps 30 --preset 4 --irefresh-type 2
"%SVTAV1_PATH%\Bin\Release\SvtAv1EncApp.exe" -i "%YUVFILE_10%" -w 1280 -h 720 -n 50 --rc 0 --qp 26 --fps 30 --preset 4 --irefresh-type 2 --input-depth 10

MSBuild svt-av1.sln /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="Release";Platform=x64;WholeProgramOptimization=PGOptimize;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%"

copy "%SVTAV1_PATH%\Bin\Release\SvtAv1EncApp.exe" "%INSTALL_DIR%"

pause