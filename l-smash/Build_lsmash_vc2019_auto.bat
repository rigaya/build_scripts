@echo off
set SEVENZIP_PATH=C:\Program Files\7-Zip\7z.exe
set OUTPUT_DIR_ONEDRIVE=C:\Users\rigaya\OneDrive\L-SMASH
set OUTPUT_DIR_GDRIVE=C:\Users\rigaya\GoogleDrive\L-SMASH
set OUTPUT_DIR_DROPBOX=C:\Users\rigaya\DropBox\L-SMASH
set OUTPUT_DIR_ZOHO=C:\Users\rigaya\Zoho Docs\L-SMASH
set ONDRIVEVIEW_PATH=C:\ProgramEx\OneDriveView\bin\OneDriveView.exe
md "%TMP_PATH%"
cd /d "%TMP_PATH%"

call Build_lsmash_vc2019.bat

for /f usebackq %%a in (`git rev-list HEAD ^| find /c /v ""`) do set REV=%%a

"%SEVENZIP_PATH%" a -xr!.git\* -t7z -mx=9 -mmt=off ..\L-SMASH-src.7z .\

set ARCHIEVE_NAME=L-SMASH rev%REV%.zip
"%SEVENZIP_PATH%" a -tzip -mx=9 -mfb=256 -mpass=15 -mmt=off "..\%ARCHIEVE_NAME%" .\CLIRelease\*.exe LICENSE ..\L-SMASH-src.7z
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_ONEDRIVE%\L-SMASH latest.zip"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_GDRIVE%\L-SMASH latest.zip"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_DROPBOX%\L-SMASH latest.zip"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_ZOHO%\L-SMASH latest.zip"


copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_ONEDRIVE%\L-SMASH_old"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_GDRIVE%\L-SMASH_old"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_DROPBOX%\L-SMASH_old"
copy /B /Y "..\%ARCHIEVE_NAME%" "%OUTPUT_DIR_ZOHO%\L-SMASH_old"


echo %REV% > "%OUTPUT_DIR_ONEDRIVE%\latest_build.txt"
echo %REV% > "%OUTPUT_DIR_GDRIVE%\latest_build.txt"
echo %REV% > "%OUTPUT_DIR_DROPBOX%\latest_build.txt"
echo %REV% > "%OUTPUT_DIR_ZOHO%\latest_build.txt"


REM "%ONDRIVEVIEW_PATH%" uploadraw "%OUTPUT_DIR_ONEDRIVE%\latest_build.txt" /L-SMASH/
REM "%ONDRIVEVIEW_PATH%" uploadraw "%OUTPUT_DIR_ONEDRIVE%\L-SMASH latest.zip" /L-SMASH/
REM "%ONDRIVEVIEW_PATH%" uploadraw "..\%ARCHIEVE_NAME%" /L-SMASH/
REM "%ONDRIVEVIEW_PATH%" uploadraw "..\%ARCHIEVE_NAME%" /L-SMASH/L-SMASH_old/

for /f "usebackq delims=" %%a in (`dir /b "%OUTPUT_DIR_ONEDRIVE%" ^| find "latest build"`) do set REMOVE_TXT=%%a
del /q "%OUTPUT_DIR_ONEDRIVE%\%REMOVE_TXT%"

type nul > "%OUTPUT_DIR_ONEDRIVE%\latest build is rev%REV%.txt"
type nul > "%OUTPUT_DIR_GDRIVE%\latest build is rev%REV%.txt"
type nul > "%OUTPUT_DIR_DROPBOX%\latest build is rev%REV%.txt"
type nul > "%OUTPUT_DIR_ZOHO%\latest build is rev%REV%.txt"

pause