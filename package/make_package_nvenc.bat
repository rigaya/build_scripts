@echo off
set CUR_DIR=%~dp0
set ENCODER_NAME=NVEnc
set ENCODER_SRC_DIR=F:\VisualStudio2019\Projects\%ENCODER_NAME%
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
start "" /wait buildReleaseVC2015.bat
start "" /wait buildReleaseVC2019.bat
cd /d "%CUR_DIR%"


set EXE_32_SRC_PATH=%ENCODER_SRC_DIR%\_build\Win32\RelStatic\%ENCODER_NAME%C.exe
set EXE_64_SRC_PATH=%ENCODER_SRC_DIR%\_build\x64\RelStatic\%ENCODER_NAME%C64.exe
set AUO_SRC_PATH=%ENCODER_SRC_DIR%\_build\Win32\Release\%ENCODER_NAME%.auo
set INI_SRC_PATH=%ENCODER_SRC_DIR%\%ENCODER_NAME%\%ENCODER_NAME%.ini
set COPY_PATH=F:\temp\

copy /y "%EXE_32_SRC_PATH%" "Y:\QSVTest\x86"
copy /y "%EXE_64_SRC_PATH%" "Y:\QSVTest\x64"
copy /y "%AUO_SRC_PATH%" "Y:\QSVTest\Aviutl\plugins"
copy /y "%INI_SRC_PATH%" "Y:\QSVTest\Aviutl\plugins"
copy /y "%EXE_32_SRC_PATH%" "%COPY_PATH%"
copy /y "%EXE_64_SRC_PATH%" "%COPY_PATH%"
copy /y "%AUO_SRC_PATH%" "%COPY_PATH%"
copy /y "%AUO_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%INI_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%AUO_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\auo"
copy /y "%INI_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\auo"
copy /y "%EXE_32_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\%ENCODER_NAME%C\x86"
copy /y "%EXE_64_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\%ENCODER_NAME%C\x64"

if exist "%ENCODER_NAME%_%ENCODER_VERSION%.zip" del "%ENCODER_NAME%_%ENCODER_VERSION%.zip"
if exist "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" del "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z"
start "7-zipà≥èk" /b "%SEVENZIP_PATH%" a -t7z -mx=9 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"
"%SEVENZIP_PATH%" a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%.zip" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"

pause