@echo off

set TMP_PATH=F:\temp\build_lsmash
set LSMASH_PATH=%TMP_PATH%\l-smash
set BUILD_PROP_PATH=C:\ProgramEx\Build_lsmash.props

if not exist "%LSMASH_PATH%" (
    git clone -b add_ver_info https://github.com/rigaya/l-smash.git "%LSMASH_PATH%"
)
cd /d "%LSMASH_PATH%"

if "%~1" == "x86" (
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat" 
    MSBuild -m L-SMASH.sln /property:Platform=Win32;Configuration="CLIRelease"
) else (
    call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 
    MSBuild -m L-SMASH.sln /property:Platform=x64;Configuration="CLIRelease"
)
