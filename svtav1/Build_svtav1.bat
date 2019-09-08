@echo off

set CMAKE_DIR=C:\Program Files\CMake\bin
set TMP_PATH=F:\temp\build_svtav1
set INSTALL_DIR=%TMP_PATH%\build
set SVTAV1_PATH=%TMP_PATH%\svt-av1
set BUILD_PROP_PATH=Build_svtav1.props

set PATH=%CMAKE_DIR%;%PATH%

rd /s /q "%SVTAV1_PATH%"
git clone https://github.com/OpenVisualCloud/SVT-AV1.git "%SVTAV1_PATH%"

cd /d "%SVTAV1_PATH%\build"
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat" x64
cmake -A x64 ^
  -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" ^
  -DCMAKE_CONFIGURATION_TYPES="Release" ^
  -DBUILD_SHARED_LIBS=OFF ^
  -DBUILD_TESTING=OFF ^
  ..

MSBuild svt-av1.sln /t:SvtAv1Enc /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="Release";Platform=x64;WholeProgramOptimization=true;ConfigurationType=StaticLibrary;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=true
MSBuild svt-av1.sln /t:SvtAv1EncApp /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="Release";Platform=x64;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false

pause