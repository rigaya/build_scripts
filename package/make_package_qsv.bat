@echo off
set CUR_DIR=%~dp0
set ENCODER_NAME=QSVEnc
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
call buildRelease.bat
cd /d "%CUR_DIR%"


set EXE_32_SRC_PATH=%ENCODER_SRC_DIR%\_build\Win32\ReleaseStatic\%ENCODER_NAME%C.exe
set EXE_64_SRC_PATH=%ENCODER_SRC_DIR%\_build\x64\ReleaseStatic\%ENCODER_NAME%C64.exe
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
copy /y "%AUO_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\auo"
copy /y "%INI_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\auo"
copy /y "%EXE_32_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\%ENCODER_NAME%C\x86"
copy /y "%EXE_64_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\%ENCODER_NAME%C\x64"

if exist "%ENCODER_NAME%_%ENCODER_VERSION%.zip" del "%ENCODER_NAME%_%ENCODER_VERSION%.zip"
if exist "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" del "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z"
start "7-zipà≥èk" /b "%SEVENZIP_PATH%" a -t7z -mx=8 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"
"%SEVENZIP_PATH%" a -tzip -mx=5 "%ENCODER_NAME%_%ENCODER_VERSION%.zip" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"

"%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\%ENCODER_NAME%C\x86\%ENCODER_NAME%C.exe" --version
"%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\%ENCODER_NAME%C\x64\%ENCODER_NAME%C64.exe" --version

pause