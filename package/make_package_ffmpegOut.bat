@echo off
set CUR_DIR=%~dp0
set ENCODER_NAME=ffmpegOut
set ENCODER_SRC_DIR=F:\VisualStudio2022\Projects\%ENCODER_NAME%
set GET_VERSION_PATH=Y:\Encoders\x64\getFileVersionInfo.exe
set SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe

set /P ENCODER_VERSION=作成する%ENCODER_NAME%のバージョン=
echo %ENCODER_NAME%_%ENCODER_VERSION%を作成します...

if not exist "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%" (
    echo "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%が存在しません"
    pause
    exit 1
)

timeout 2

cd /d "%ENCODER_SRC_DIR%"
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars32.bat" x86
msbuild %ENCODER_NAME%.sln /t:build /p:Configuration=Release;Platform="Win32"
cd /d "%CUR_DIR%"


set AUO_SRC_PATH=%ENCODER_SRC_DIR%\Release\%ENCODER_NAME%.auo
set INI_SRC_PATH=%ENCODER_SRC_DIR%\Release\%ENCODER_NAME%.ini
set STG_SRC_PATH=%ENCODER_SRC_DIR%\ffmpegOut\stg
set TXT_SRC_PATH=%ENCODER_SRC_DIR%\ffmpegOut_readme.txt
set COPY_PATH=F:\temp\

call :CheckEXEVersion %ENCODER_VERSION% "%AUO_SRC_PATH%"

copy /y "%AUO_SRC_PATH%" "%COPY_PATH%"
copy /y "%AUO_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%INI_SRC_PATH%" "C:\ProgramEx\Aviutl\plugins"
copy /y "%AUO_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins"
copy /y "%INI_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins"
xcopy /e /y "%STG_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins\ffmpegOut_stg\"
copy /y "%TXT_SRC_PATH%" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"

if exist "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins\ffmpegOut_stg\前回出力.stg" del "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\plugins\ffmpegOut_stg\前回出力.stg"
if exist "%ENCODER_NAME%_%ENCODER_VERSION%.zip" del "%ENCODER_NAME%_%ENCODER_VERSION%.zip"
if exist "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" del "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z"
REM start "7-zip圧縮" /b "%SEVENZIP_PATH%" a -t7z -mx=9 -mmt=off "%ENCODER_NAME%_%ENCODER_VERSION%_7zip.7z" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%"
"%SEVENZIP_PATH%" a -tzip -mx=9 -mfb=256 -mpass=15 -mmt "%ENCODER_NAME%_%ENCODER_VERSION%.zip" "%CUR_DIR%\%ENCODER_NAME%_%ENCODER_VERSION%\*"

pause
exit /b

:CheckEXEVersion
set ENC_VERSION=%~1
set EXE_PATH=%~2
set EXE_VER_RESULT=
for /f "usebackq delims=" %%i in (`CALL "%GET_VERSION_PATH%" "%EXE_PATH%"`) DO (
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