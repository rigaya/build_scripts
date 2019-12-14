@echo off
cd /d "%~dp0"

rem VC2017
rem call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat"
rem call "%VS150COMNTOOLS%\..\..\VC\Auxiliary\Build\vcvarsall.bat" x86

rem VC2019
call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\Common7\Tools\VsDevCmd.bat"
call "%VS160COMNTOOLS%\..\..\VC\Auxiliary\Build\vcvarsall.bat" x86

"%~dp0msys2_shell.cmd" -mingw32 -use-full-path