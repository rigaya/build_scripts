@echo off

set TMP_PATH=F:\temp\lsmash_build
set LSMASH_PATH=%TMP_PATH%\l-smash
set BUILD_PROP_PATH=C:\ProgramEx\Build_lsmash.props
set LSMASH_PATCH=C:\ProgramEx\lsmash.diff

rd /s /q "%LSMASH_PATH%"
git clone -b fast https://github.com/nekopanda/l-smash.git "%LSMASH_PATH%"

cd /d "%LSMASH_PATH%"

set PLATFORM=Win32
set ARCH=x86
if "%1"=="x86" (
    set PLATFORM=Win32
    set ARCH=x86
)
if "%1"=="x64" (
    set PLATFORM=x64
    set ARCH=x64
)

git apply "%LSMASH_PATCH%"

call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" %ARCH%

MSBuild L-SMASH.sln /t:liblsmash /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=%PLATFORM%;WholeProgramOptimization=true;ConfigurationType=StaticLibrary;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:cli /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=%PLATFORM%;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:muxer /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=%PLATFORM%;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:remuxer /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=%PLATFORM%;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:boxdumper /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=%PLATFORM%;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:timelineeditor /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=%PLATFORM%;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
