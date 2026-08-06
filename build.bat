@echo off
rem See 'readme.md' file

setlocal enabledelayedexpansion

set PLATFORM=%1
if "%PLATFORM%" == "" set PLATFORM=Win32
if "%PLATFORM%" neq "Win32" if "%PLATFORM%" neq "Win64" (
  echo Unknown plaform, use Win32 or Win64
  exit /B 1
)

if "%PROCESSOR_ARCHITECTURE%"=="x86" (
  set "PROGRAMFILES32=%ProgramFiles%"
  set "PROGRAMFILES64=%ProgramW6432%"
) else if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
  set "PROGRAMFILES32=%ProgramFiles(x86)%"
  set "PROGRAMFILES64=%ProgramFiles%"
) else (
  echo Unrecognized architecture %PROCESSOR_ARCHITECTURE%
  exit /B 1
)

set BDS=%PROGRAMFILES32%\Embarcadero\Studio\22.0

set VS_PATH_REL=Microsoft Visual Studio\2022
set MSBUILD_REL=MSBuild\Current\Bin\MSBuild.exe
rem Visual Studio Community 2022 (development machine)
set MSBUILD_COMMUNITY=%PROGRAMFILES64%\%VS_PATH_REL%\Community\%MSBUILD_REL%
set MSBUILD=%MSBUILD_COMMUNITY%
rem Visual Studio 2022 Build Tools (build server)
if not exist "%MSBUILD%" set MSBUILD=%PROGRAMFILES32%\%VS_PATH_REL%\BuildTools\%MSBUILD_REL%
rem Visual Studio Enterprise 2022 (CI runner)
if not exist "%MSBUILD%" set MSBUILD=%PROGRAMFILES64%\%VS_PATH_REL%\Enterprise\%MSBUILD_REL%
rem Try vswhere to locate MSBuild (any edition)
if not exist "!MSBUILD!" (
  set "VSWHERE=%PROGRAMFILES32%\Microsoft Visual Studio\Installer\vswhere.exe"
  if exist "!VSWHERE!" (
    for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`) do set "MSBUILD=%%i"
  )
)
rem Try PATH (e.g. set up by microsoft/setup-msbuild action)
if not exist "!MSBUILD!" (
  for /f "usebackq tokens=*" %%i in (`where msbuild 2^>nul`) do (
    if not exist "!MSBUILD!" set MSBUILD=%%i
  )
)
if not exist "!MSBUILD!" echo Cannot find MSBUILD (!MSBUILD!, %MSBUILD_COMMUNITY%), install Build Tools for Visual Studio 2022 & exit /B 1

set WITH_DOTNET=1
if "%BUILD_TARGET%"=="" set BUILD_TARGET=Build
if "%BUILD_CONFIG%"=="" set BUILD_CONFIG=Release

set BUILDTOOLS=%~dp0\buildtools

cd libs
set INTERM_PATH=%~dp0\source
call buildlibs.bat %PLATFORM%
if errorlevel 1 echo Error building libs & exit /B 1
set INTERM_PATH=

cd ..\source
set BDS_BUILD_PROPERTIES=RELEASE_TYPE=%RELEASE_TYPE%;CONFIG=%BUILD_CONFIG%;INTERM_PATH=.;FINAL_PATH=.
"%MSBUILD%" WinSCP.groupproj /t:%BUILD_TARGET% /p:%BDS_BUILD_PROPERTIES%;Platform=%PLATFORM%
if "%PLATFORM%" == "Win32" "%MSBUILD%" DragExt.cbproj /t:%BUILD_TARGET% /p:%BDS_BUILD_PROPERTIES%;Platform=Win64

if "%WITH_DOTNET%"=="0" goto SKIP_DOTNET
cd ..\dotnet
set DOTNET_BUILD_PROPERTIES=INTERM_PATH=.;FINAL_PATH=.
dotnet restore WinSCPnet.csproj -p:%DOTNET_BUILD_PROPERTIES%
dotnet build WinSCPnet.csproj -c %BUILD_CONFIG% -p:%DOTNET_BUILD_PROPERTIES%
:SKIP_DOTNET
