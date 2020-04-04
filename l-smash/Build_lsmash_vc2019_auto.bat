@echo off
set SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe
set OUTPUT_DIR_ONEDRIVE=C:\Users\rigaya\OneDrive\L-SMASH
set OUTPUT_DIR_GDRIVE=C:\Users\rigaya\GoogleDrive\L-SMASH
set OUTPUT_DIR_DROPBOX=C:\Users\rigaya\DropBox\L-SMASH
set OUTPUT_DIR_WITH_PASS=Y:\temp
set SEVEN_ZIP_PASS=rigaya
set TMP_PATH=F:\temp\build_lsmash
set SUB_BAT=%~dp0Build_lsmash_vc2019.bat

if exist "%TMP_PATH%" rmdir /s /q "%TMP_PATH%"
md "%TMP_PATH%"
cd /d "%TMP_PATH%"

call :BuildLSMASH x86
call :BuildLSMASH x64

cd "%TMP_PATH%\l-smash"
set ARCHIEVE_SRC=L-SMASH-%REV%-src.7z
del /s /q "%ARCHIEVE_SRC%"
"%SEVENZIP_PATH%" a -xr!.git\* -xr!Win32\* -xr!x64\* -xr!CLIRelease\* -t7z -mx=9 -mmt=off "..\%ARCHIEVE_SRC%" .\
copy /B /Y "..\%ARCHIEVE_SRC%" "%OUTPUT_DIR_ONEDRIVE%\src"
copy /B /Y "..\%ARCHIEVE_SRC%" "%OUTPUT_DIR_GDRIVE%\src"
copy /B /Y "..\%ARCHIEVE_SRC%" "%OUTPUT_DIR_DROPBOX%\src"
exit /b

:BuildLSMASH
set ARCH=%1
call "%SUB_BAT%" %ARCH%

cd "%TMP_PATH%\l-smash"
for /f usebackq %%a in (`git rev-list HEAD ^| find /c /v ""`) do set REV=%%a

if "%ARCH%" == "x86" (
    set PLATFORM=Win32
) else (
    set PLATFORM=x64
)
set ARCHIEVE_NAME=L-SMASH_rev%REV%_%ARCH%.zip
del /s /q "..\%ARCHIEVE_NAME%"
"%SEVENZIP_PATH%" a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "..\%ARCHIEVE_NAME%" .\%PLATFORM%\CLIRelease\*.exe LICENSE

del "%OUTPUT_DIR_ONEDRIVE%\L-SMASH_rev*_%ARCH%.zip"
del "%OUTPUT_DIR_GDRIVE%\L-SMASH_rev*_%ARCH%.zip"
del "%OUTPUT_DIR_DROPBOX%\L-SMASH_rev*_%ARCH%.zip"

copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_ONEDRIVE%"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_GDRIVE%"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_DROPBOX%"

copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_ONEDRIVE%\old"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_GDRIVE%\old"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_DROPBOX%\old"

set ARCHIEVE_NAME=L-SMASH_rev%REV%_%ARCH%_with_pass.7z
del /s /q "..\%ARCHIEVE_NAME%"
"%SEVENZIP_PATH%" a -t7z -p%SEVEN_ZIP_PASS% -mhe=on -mx=9 -mmt=off "..\%ARCHIEVE_NAME%" .\%PLATFORM%\CLIRelease\*.exe LICENSE

copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_WITH_PASS%"

exit /b

