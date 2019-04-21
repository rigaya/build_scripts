@echo off

set TMP_PATH=F:\temp\lsmash_build
set LSMASH_PATH=%TMP_PATH%\l-smash
set BUILD_PROP_PATH=C:\ProgramEx\Build_lsmash.props

rd /s /q "%LSMASH_PATH%"
git clone https://github.com/l-smash/l-smash.git "%LSMASH_PATH%"

cd /d "%LSMASH_PATH%"

call "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars32.bat" x86

MSBuild L-SMASH.sln /t:liblsmash /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=Win32;WholeProgramOptimization=true;ConfigurationType=StaticLibrary;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:cli /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=Win32;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:muxer /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=Win32;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:remuxer /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=Win32;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:boxdumper /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=Win32;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false
MSBuild L-SMASH.sln /t:timelineeditor /property:WindowsTargetPlatformVersion=10.0;PlatformToolset=v142;Configuration="CLIRelease";Platform=Win32;WholeProgramOptimization=true;ForceImportBeforeCppTargets="%BUILD_PROP_PATH%" /p:BuildProjectReferences=false

pause