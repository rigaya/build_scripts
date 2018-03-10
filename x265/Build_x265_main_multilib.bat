@echo off
cd /d "%~dp0"
call Build_x265_settings.bat

if "%3" == "1" (
    set PGO_APPENDIX=_pgo
    set LTCG_OPTION=PGInstrument
    set MULTI_LIB_LINK=-D EXTRA_LIB:STRING="x265-static-main10.lib" -D LINKED_10BIT:BOOL=ON
    REM set MULTI_LIB_LINK=-D EXTRA_LIB:STRING="x265-static-main10.lib;x265-static-main12.lib" -D LINKED_10BIT:BOOL=ON -D LINKED_12BIT:BOOL=ON
) else (
    set PGO_APPENDIX=
    set LTCG_OPTION=false
    set MULTI_LIB_LINK=-D EXTRA_LIB:STRING="x265-static-main10.lib;x265-static-main12.lib" -D LINKED_10BIT:BOOL=ON -D LINKED_12BIT:BOOL=ON
)

set FORX64=%1
if "%FORX64%" == "1" (
    set ARCH=x64
    set ARCH_VC=x64
    set BUILD_PATH=%X265_PATH%\build\vc15-x86_64%PGO_APPENDIX%
    set CMAKE_VS_TYPE=Visual Studio 15 2017 Win64
) else (
    set MULTI_LIB_LINK=
    set PGO_APPENDIX=
    set ARCH=x86
    set ARCH_VC=Win32
    set BUILD_PATH=%X265_PATH%\build\vc15-x86%PGO_APPENDIX%
    set CMAKE_VS_TYPE=Visual Studio 15 2017
)

call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat"
call "%VS150COMNTOOLS%\..\..\VC\Auxiliary\Build\vcvarsall.bat" %ARCH_VC%

if not exist "%BUILD_PATH%" mkdir "%BUILD_PATH%"
cd /d "%BUILD_PATH%"

rd /s /q 8bit
rd /s /q 10bit
rd /s /q 12bit

mkdir 8bit

if "%ARCH%" == "x86" goto BUILD_8BIT
mkdir 12bit
mkdir 10bit

if "%LTCG_OPTION%" == "PGInstrument" goto START_10BIT

cd "%BUILD_PATH%\12bit"
cmake -D STATIC_LINK_CRT:BOOL=ON ^
    -D ENABLE_SHARED:BOOL=OFF ^
    -D CMAKE_CXX_FLAGS_RELEASE:STRING="%VC_OPTIONS%" ^
    -D CMAKE_C_FLAGS_RELEASE:STRING="%VC_OPTIONS%" ^
    -D CMAKE_MODULE_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_MODULE_OPTIONS%" ^
    -D CMAKE_SHARED_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_SHARED_OPTIONS%" ^
    -D HIGH_BIT_DEPTH:BOOL=ON ^
    -D EXPORT_C_API:BOOL=OFF ^
    -D ENABLE_CLI:BOOL=OFF ^
    -D MAIN12:BOOL=ON ^
    -G "%CMAKE_VS_TYPE%" ..\..\..\source

MSBuild /property:Configuration="Release";WholeProgramOptimization=%LTCG_OPTION% x265.sln

if not exist Release\x265-static.lib (
  msg "%username%" "12bit build failed"
  exit 1
)
copy /y Release\x265-static.lib ..\8bit\x265-static-main12.lib

:START_10BIT
cd "%BUILD_PATH%\10bit"
cmake -D STATIC_LINK_CRT:BOOL=ON ^
    -D ENABLE_SHARED:BOOL=OFF ^
    -D CMAKE_CXX_FLAGS_RELEASE:STRING="%VC_OPTIONS%" ^
    -D CMAKE_C_FLAGS_RELEASE:STRING="%VC_OPTIONS%" ^
    -D CMAKE_MODULE_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_MODULE_OPTIONS%" ^
    -D CMAKE_SHARED_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_SHARED_OPTIONS%" ^
    -D HIGH_BIT_DEPTH:BOOL=ON ^
    -D EXPORT_C_API:BOOL=OFF ^
    -D ENABLE_CLI:BOOL=OFF ^
    -G "%CMAKE_VS_TYPE%" ..\..\..\source

MSBuild /property:Configuration="Release";WholeProgramOptimization=%LTCG_OPTION% x265.sln
copy/y Release\x265-static.lib ..\8bit\x265-static-main10.lib


cd "%BUILD_PATH%\8bit"
if not exist x265-static-main10.lib (
  msg "%username%" "10bit build failed"
  exit 1
)

:BUILD_8BIT
cd "%BUILD_PATH%\8bit"
cmake -D STATIC_LINK_CRT:BOOL=ON ^
    -D ENABLE_SHARED:BOOL=OFF ^
    -D CMAKE_CXX_FLAGS_RELEASE:STRING="%VC_OPTIONS%" ^
    -D CMAKE_C_FLAGS_RELEASE:STRING="%VC_OPTIONS%" ^
    -D CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_EXE_OPTIONS%" ^
    -D CMAKE_MODULE_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_MODULE_OPTIONS%" ^
    -D CMAKE_SHARED_LINKER_FLAGS_RELEASE:STRING="%VC_LINKER_SHARED_OPTIONS%" ^
    %MULTI_LIB_LINK% -G "%CMAKE_VS_TYPE%" ..\..\..\source

MSBuild /property:Configuration="Release";WholeProgramOptimization=%LTCG_OPTION% x265.sln
rem PGOƒrƒ‹ƒh‚ð‚µ‚È‚¢ê‡‚Í‚±‚ê‚ÅI—¹
if not "%LTCG_OPTION%" == "PGInstrument" goto CREATE_PACKAGE

release\x265.exe --crf 23 --input-depth 8 --output-depth 8 --frames 60 --preset medium -o nul "%TEST_MOVIE%"
release\x265.exe --crf 23 --input-depth 8 --output-depth 8 --frames 60 --preset slow   --amp --weightb -o nul "%TEST_MOVIE%"
release\x265.exe --crf 23 --input-depth 8 --output-depth 8 --frames 60 --preset slower --amp --weightb -o nul "%TEST_MOVIE%"

if "%ARCH%" == "x86" goto BUILD_OPTIMIZED_EXE

release\x265.exe --crf 23 --input-depth 8 --output-depth 10 --frames 60 --preset medium -o nul "%TEST_MOVIE%"
release\x265.exe --crf 23 --input-depth 8 --output-depth 10 --frames 60 --preset slow   --amp --weightb -o nul "%TEST_MOVIE%"
release\x265.exe --crf 23 --input-depth 8 --output-depth 10 --frames 60 --preset slower --amp --weightb -o nul "%TEST_MOVIE%"

if "%LTCG_OPTION%" == "PGInstrument" goto BUILD_OPTIMIZED_EXE

release\x265.exe --crf 23 --input-depth 8 --output-depth 12 --frames 60 --preset medium -o nul "%TEST_MOVIE%"
release\x265.exe --crf 23 --input-depth 8 --output-depth 12 --frames 60 --preset slow   --amp --weightb -o nul "%TEST_MOVIE%"
release\x265.exe --crf 23 --input-depth 8 --output-depth 12 --frames 60 --preset slower --amp --weightb -o nul "%TEST_MOVIE%"

:BUILD_OPTIMIZED_EXE
MSBuild /property:Configuration="Release";WholeProgramOptimization=PGOptimize x265.sln

:CREATE_PACKAGE
set X265_VER=
call :get_x265_ver "release\x265.exe"
echo %X265_VER%
move /y release\x265.exe "release\x265_%X265_VER%_%ARCH%.exe"

cd release
if not "%2" == "1" goto end
del /Q /F "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip"
del /Q /F "%ARCHIEVE_PATH_ONEDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip"
del /Q /F "%ARCHIEVE_PATH_DROPBOX%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip"

"%SEVENZIP_PATH%" a -tZIP -mx=8 -mmt=off "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip" "x265_%X265_VER%_%ARCH%.exe" "%GPL_LICENSE_PATH%"
copy /y "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip" "%ARCHIEVE_PATH_ONEDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip"
copy /y "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip" "%ARCHIEVE_PATH_DROPBOX%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip"

copy /y "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip" "%ARCHIEVE_PATH_GDRIVE%\x265_latest_%ARCH%%PGO_APPENDIX%.zip"
copy /y "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip" "%ARCHIEVE_PATH_ONEDRIVE%\x265_latest_%ARCH%%PGO_APPENDIX%.zip"

rem OneDrive
REM "%ONEDRIVEVIEW_PATH%" uploadraw "%ARCHIEVE_PATH_GDRIVE%\old\x265_%X265_VER%_%ARCH%%PGO_APPENDIX%.zip" /x265/old/
REM "%ONEDRIVEVIEW_PATH%" uploadraw "%ARCHIEVE_PATH_GDRIVE%\x265_latest_%ARCH%%PGO_APPENDIX%.zip" /x265/

move "x265_%X265_VER%_%ARCH%.exe" C:\ProgramEx\Aviutl_shared

:end
goto :EOF



:get_x265_ver
%1 --version 2> x265_version.txt
findstr "version" x265_version.txt > x265_version_tmp.txt
for /f "delims=" %%t in (x265_version_tmp.txt) do set X265_VER=%%t
set X265_VER=%X265_VER:~34%
set X265_VER=%X265_VER:~0,-13%
del x265_version.txt
del x265_version_tmp.txt
exit /b

