@echo off
cd /d "%~dp0"
call Build_x265_settings.bat

rem ダウンロード
rd /s /q "%TMP_PATH%"
md "%TMP_PATH%"
cd /d "%TMP_PATH%"
rd /s /q x265
hg clone https://bitbucket.org/multicoreware/x265 "%X265_PATH%"

rem 準備
:start
rd /s /q "%TMP_PATH%\x265_src"
md "%TMP_PATH%\x265_src"
md "%ARCHIEVE_PATH_GDRIVE%"
md "%ARCHIEVE_PATH_GDRIVE%\src"
md "%ARCHIEVE_PATH_ONEDRIVE%"
md "%ARCHIEVE_PATH_ONEDRIVE%\src"
md "%ARCHIEVE_PATH_DROPBOX%"
md "%ARCHIEVE_PATH_DROPBOX%\src"
rem ソースの圧縮
del "%TMP_PATH%\x265_src.7z"
echo \.hg\ > "%TMP_PATH%\exclude.txt"
xcopy "%X265_PATH%" "%TMP_PATH%\x265_src" /EXCLUDE:%TMP_PATH%\exclude.txt /e /y /q

rem バージョンチェック
set X265_VER=
call :get_x265_ver
echo %X265_VER%
set LATEST_VER=
for /f "delims=" %%t in (%ARCHIEVE_LATEST_BUILD_PATH%) do set LATEST_VER=%%t
if "%LATEST_VER%" == "%X265_VER%" GOTO :EOF

rem hg import --no-commit https://patches.videolan.org/patch/12701/raw/

rem x86版ビルド
start "x265_build" /min cmd.exe /c "%MAIN_BAT_PATH%" 0 1 1

rem x64版ビルド 
start "x265_build" /min cmd.exe /c "%MAIN_BAT_PATH%" 1 1 0

rem x64版ビルド (LTCG)
start "x265_build" /min cmd.exe /c "%MAIN_BAT_PATH%" 1 1 1

rem 配置
"%SEVENZIP_PATH%" a -t7z -mx=9 -mmt=off "%TMP_PATH%\x265_src.7z" "%TMP_PATH%\x265_src\"


copy "%TMP_PATH%\x265_src.7z" "%ARCHIEVE_PATH_ONEDRIVE%\src\x265_%X265_VER%_src.7z"
copy "%TMP_PATH%\x265_src.7z" "%ARCHIEVE_PATH_GDRIVE%\src\x265_%X265_VER%_src.7z"
copy "%TMP_PATH%\x265_src.7z" "%ARCHIEVE_PATH_DROPBOX%\src\x265_%X265_VER%_src.7z"
echo %X265_VER% > "%ARCHIEVE_LATEST_BUILD_PATH%"
copy /y "%ARCHIEVE_LATEST_BUILD_PATH%" "%ARCHIEVE_PATH_ONEDRIVE%"
copy /y "%ARCHIEVE_LATEST_BUILD_PATH%" "%ARCHIEVE_PATH_DROPBOX%"

for /f "usebackq delims=" %%a in (`dir /b "%ARCHIEVE_PATH_ONEDRIVE%" ^| find "current version"`) do set REMOVE_TXT=%%a
del /q "%ARCHIEVE_PATH_ONEDRIVE%\%REMOVE_TXT%"
for /f "usebackq delims=" %%a in (`dir /b "%ARCHIEVE_PATH_GDRIVE%" ^| find "current version"`) do set REMOVE_TXT=%%a
del /q "%ARCHIEVE_PATH_GDRIVE%\%REMOVE_TXT%"
for /f "usebackq delims=" %%a in (`dir /b "%ARCHIEVE_PATH_DROPBOX%" ^| find "current version"`) do set REMOVE_TXT=%%a
del /q "%ARCHIEVE_PATH_DROPBOX%\%REMOVE_TXT%"

echo %X265_VER% > "%ARCHIEVE_PATH_GDRIVE%\current version is %X265_VER%.txt"
echo %X265_VER% > "%ARCHIEVE_PATH_ONEDRIVE%\current version is %X265_VER%.txt"
echo %X265_VER% > "%ARCHIEVE_PATH_DROPBOX%\current version is %X265_VER%.txt"

GOTO :EOF


:get_x265_ver
mkdir "%X265_PATH%\build\vc15-x86"
cd "%X265_PATH%\build\vc15-x86"
cmake  -G "Visual Studio 15 2017" ..\..\source > cmake_log.txt
findstr "version" cmake_log.txt > x265_version_tmp.txt
for /f "delims=" %%t in (x265_version_tmp.txt) do set X265_VER=%%t
set X265_VER=%X265_VER:~16%
set X265_VER=%X265_VER:~0,-13%
del x265_version.txt
del x265_version_tmp.txt
exit /b

