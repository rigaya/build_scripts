@echo off
set CUR_DIR=%~dp0
set ENCODER_NAME=x265guiEx
set ENCODER_SRC_DIR=F:\Visual Studio 2015\Projects\%ENCODER_NAME%
set SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe

set /P ENCODER_VERSION=çÏê¨Ç∑ÇÈ%ENCODER_NAME%ÇÃÉoÅ[ÉWÉáÉì=
echo %ENCODER_NAME%_%ENCODER_VERSION%ÇçÏê¨ÇµÇ‹Ç∑...

if not exist "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%" (
    echo "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%Ç™ë∂ç›ÇµÇ‹ÇπÇÒ"
    pause
    exit 1
)

timeout 2

cd /d "%ENCODER_SRC_DIR%"
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat" x86
msbuild x265guiEx.sln /t:build /p:Configuration=Release;Platform="Win32"
cd /d "%CUR_DIR%"


set AUO_SRC_PATH=%ENCODER_SRC_DIR%\Release\%ENCODER_NAME%.auo
set INI_SRC_PATH=%ENCODER_SRC_DIR%\Release\%ENCODER_NAME%.ini
set COPY_PATH=F:\temp\

copy /y "%AUO_SRC_PATH%" "%COPY_PATH%"
copy /y "%AUO_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%INI_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%AUO_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\auo"
copy /y "%INI_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\auo"

if exist "%ENCODER_NAME%_%ENCODER_VERSION%.zip" del "%ENCODER_NAME%_%ENCODER_VERSION%.zip"
if exist "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" del "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z"
start "7-zipà≥èk" /b "%SEVENZIP_PATH%" a -t7z -mx=9 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"
"%SEVENZIP_PATH%" a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%.zip" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"

pause