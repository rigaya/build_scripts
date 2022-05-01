@echo off
set CUR_DIR=%~dp0
set ENCODER_NAME=VCEEnc
set ENCODER_SRC_DIR=F:\VisualStudio2022\Projects\%ENCODER_NAME%
set SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe

set /P ENCODER_VERSION=çÏê¨Ç∑ÇÈ%ENCODER_NAME%ÇÃÉoÅ[ÉWÉáÉì=
echo %ENCODER_NAME%_%ENCODER_VERSION%ÇçÏê¨ÇµÇ‹Ç∑...

if not exist "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%" (
    echo "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%Ç™ë∂ç›ÇµÇ‹ÇπÇÒ"
    pause
    exit 1
)

timeout 2

cd /d "%ENCODER_SRC_DIR%\BuildParallel"
call rebuildRelease.bat
cd /d "%CUR_DIR%"


set EXE_32_SRC_PATH=%ENCODER_SRC_DIR%\_build\Win32\RelStatic\%ENCODER_NAME%C.exe
set EXE_64_SRC_PATH=%ENCODER_SRC_DIR%\_build\x64\RelStatic\%ENCODER_NAME%C64.exe
set AUO_SRC_PATH=%ENCODER_SRC_DIR%\_build\Win32\Release\%ENCODER_NAME%.auo
set INI_SRC_PATH=%ENCODER_SRC_DIR%\%ENCODER_NAME%\%ENCODER_NAME%.ini
set COPY_PATH=F:\temp\

set EXE_VER_RESULT=
for /f "usebackq tokens=3" %%i in (`"%EXE_64_SRC_PATH%" --version`) DO (
    set EXE_VER_RESULT=%%i
    goto GOT_EXE_VER
)
:GOT_EXE_VER
if not "%EXE_VER_RESULT%" == "%ENCODER_VERSION%" (
    echo exe version do not match! set %ENCODER_VERSION%, exe %EXE_VER_RESULT%
    pause
    exit 1
)
echo check exe version OK! set %ENCODER_VERSION%, exe %EXE_VER_RESULT%

"%EXE_64_SRC_PATH%" --check-avcodec-dll
if not "%errorlevel%" == "0" (
    pause
    exit
)

copy /y "%EXE_32_SRC_PATH%" "Y:\Encoders\x86"
copy /y "%EXE_64_SRC_PATH%" "Y:\Encoders\x64"
copy /y "%EXE_64_SRC_PATH%" "Y:\Encoders\x64\%ENCODER_NAME%C64_%ENCODER_VERSION%.exe"
copy /y "%AUO_SRC_PATH%" "Y:\Encoders\Aviutl\plugins"
copy /y "%INI_SRC_PATH%" "Y:\Encoders\Aviutl\plugins"
copy /y "%EXE_32_SRC_PATH%" "%COPY_PATH%"
copy /y "%EXE_64_SRC_PATH%" "%COPY_PATH%"
copy /y "%AUO_SRC_PATH%" "%COPY_PATH%"
copy /y "%AUO_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%INI_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%AUO_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins"
copy /y "%INI_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins"
copy /y "%EXE_32_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\exe_files\%ENCODER_NAME%C\x86"
copy /y "%EXE_64_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\exe_files\%ENCODER_NAME%C\x64"

set PKG_EXE_32=%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\exe_files\%ENCODER_NAME%C\x86\%ENCODER_NAME%C.exe
call :CheckEXEVersion %ENCODER_VERSION% "%PKG_EXE_32%"
call :CheckEXEDll "%PKG_EXE_32%"
REM call :CheckSimpleRun "%PKG_EXE_32%"

set PKG_EXE_64=%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\exe_files\%ENCODER_NAME%C\x64\%ENCODER_NAME%C64.exe
call :CheckEXEVersion %ENCODER_VERSION% "%PKG_EXE_64%"
call :CheckEXEDll "%PKG_EXE_64%"
call :CheckSimpleRun "%PKG_EXE_64%"

if exist "%ENCODER_NAME%_%ENCODER_VERSION%.zip" del "%ENCODER_NAME%_%ENCODER_VERSION%.zip"
if exist "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" del "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z"
REM start "7-zipà≥èk" /b "%SEVENZIP_PATH%" a -t7z -mx=7 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"
"%SEVENZIP_PATH%" a -tzip -mx=9 -mfb=256 -mpass=15 -mmt "Aviutl_%ENCODER_NAME%_%ENCODER_VERSION%.zip" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\*"

"%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\exe_files\%ENCODER_NAME%C\x86\%ENCODER_NAME%C.exe" --version
"%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\exe_files\%ENCODER_NAME%C\x64\%ENCODER_NAME%C64.exe" --version

pause
exit /b

:CheckEXEVersion
set ENC_VERSION=%1
set EXE_PATH=%2
set EXE_VER_RESULT=
for /f "usebackq tokens=3" %%i in (`"%EXE_PATH%" --version`) DO (
    set EXE_VER_RESULT=%%i
    goto GOT_EXE_VER
)
:GOT_EXE_VER
if not "%EXE_VER_RESULT%" == "%ENC_VERSION%" (
    echo exe version do not match! set %ENC_VERSION%, exe %EXE_VER_RESULT%
    pause
    exit /b 1
)
echo check exe version OK! set %ENC_VERSION%, exe %EXE_VER_RESULT%
exit /b 0

:CheckEXEDll
set EXE_PATH=%1
echo check dll %EXE_PATH%
"%EXE_PATH%" --check-avcodec-dll
if not "%errorlevel%" == "0" (
    pause
    exit /b 1
)
exit /b 0

:CheckSimpleRun
set EXE_PATH=%1
set INPUT_PATH=Y:\Encoders\sakura_op.mp4
set OUTPUT_PATH=Y:\temp\test_pkg.mp4
"%EXE_PATH%" -i "%INPUT_PATH%" --audio-codec aac --output-res 512x288 -o "%OUTPUT_PATH%"
if not "%errorlevel%" == "0" (
    pause
    exit /b 1
)
exit /b 0