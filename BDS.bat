@echo off
setlocal enableextensions enabledelayedexpansion

set SELF_NAME=%~n0
set SELF_VS=3.0.0

:: Análisis de argumentos
for %%A in (%*) do (
  set "arg=%%~A"
  set "firstChar=!arg:~0,1!"
  rem Primer argumento sin "-" se interpreta como el comando
  if not defined CMD (
    if not "!firstChar!"=="-" (
      set "CMD=!arg!"
    )
  ) 
  rem Argumento tipo --key=value
  if "!arg:~0,2!"=="--" (
    set "kvpair=!arg:~2!"
    for /f "tokens=1,* delims=:" %%K in ("!kvpair!") do (
      if "%%L"=="" (
        set "ARG_%%K=true"
      ) else (
        set "ARG_%%K=%%L"
      )
    )
  )
)
if not defined CMD set "CMD=start"

:: to inspect command line arguments
:: echo Command: %CMD% Args:
:: SET ARG_

set "PRJ_ROOT_KEY=USR_PRJ"
:: Current dir without trailing backslash
set WORK_DIR=%~dp0
IF %WORK_DIR:~-1%==\ SET WORK_DIR=%WORK_DIR:~0,-1%


:: default PRJ vars
set "PRJ_DIR=%WORK_DIR%"
set "PRJ_VENDOR_DIR=%PRJ_DIR%\vendor"
set "PRJ_OUT_DIR=%PRJ_DIR%\out"
for /R "%PRJ_DIR%" %%F in (*.groupproj) do (
    set "PRJ_BUILD_FILE=%%F"
    goto :found
)
for /R "%PRJ_DIR%" %%F in (*.dproj) do (
    set "PRJ_BUILD_FILE=%%F"
    goto :found
)
:found

for %%i IN ("%PRJ_DIR%") DO set "PRJ_NAME=%%~ni"

set "PRJ_REG_KEY=%PRJ_ROOT_KEY%\%PRJ_NAME%"

:: load project specific settings so we can override defaults
call "%WORK_DIR%\project.cmd"


:: add vendor_bin to path, so you can install your vendor pkg
set PATH=%PATH%;%PRJ_VENDOR_DIR%\bin

:: create output dir
mkdir "%PRJ_OUT_DIR%" 2>nul

if (%PRJ_IDE%)==() goto :ERR_PRJ_IDE_NOT_DEFINED
:: select ide version from PRJ_IDE: remove last digit & remove D prefix
SET IDE_VER=%PRJ_IDE:~0,-1%
SET IDE_VER=%IDE_VER:~1%

:: find delphi registry key
set "delphi_reg="
if %IDE_VER% LEQ 7 (
  set "delphi_brand=Borland"
  set "delphi_brand_base=Delphi"
) else (
  if !IDE_VER! LEQ 14 (
    set /A IDE_VER-=6
    set "delphi_brand=Borland"
    set "delphi_brand_base=BDS"
  ) else (
    set "delphi_brand=Embarcadero"
    set "delphi_brand_base=BDS"
    if !IDE_VER! LEQ 19 (
      set /A IDE_VER-=7
    ) else (
      set /A IDE_VER-=6
    )
  )
)
SET "IDE_VER=%IDE_VER%.0"
set "BDS_APP_REG_KEY=App"
if (%ARG_64%)==(true) (
echo Using 64-bit IDE
set "BDS_APP_REG_KEY=App x64"
shift /1
)


if (%delphi_brand%)==() goto :ERR_IDE_VS_NOT_FOUND
set "delphi_reg=HKCU\Software\%delphi_brand%\%delphi_brand_base%\!IDE_VER!"
:: Get BDS root path & BDS app from Windows Registry
for /f "skip=2 tokens=2,*" %%a in ('reg query "%delphi_reg%" /v "RootDir" 2^>nul') do set "BDS=%%~b"

if (%ARG_64%)==(true) (
  for /f "skip=2 tokens=3,*" %%a in ('reg query "%delphi_reg%" /v "%BDS_APP_REG_KEY%" 2^>nul') do set "BDSApp=%%~b"
) else (
  for /f "skip=2 tokens=2,*" %%a in ('reg query "%delphi_reg%" /v "%BDS_APP_REG_KEY%" 2^>nul') do set "BDSApp=%%~b"
)
set BDS=!BDS:~0,-1!

if ("%BDSApp%")==("") goto :ERR_IDE_VS_NOT_FOUND
set "delphi_reg=HKCU\Software\%delphi_brand%\%PRJ_REG_KEY%\!IDE_VER!"
if (%ARG_64%)==(true) (
  set "BDSbin=%BDS%\bin64"
) else (
  set "BDSbin=%BDS%\bin"
)
:: clear aux variables
set "delphi_brand="
set "delphi_brand_base="
set "ARG_64="
set "BDS_APP_REG_KEY="

:: set IDE DefaultProjectsDirectory 
reg add "%delphi_reg%\Globals" /v "DefaultProjectsDirectory" /t REG_SZ /d "%PRJ_DIR%" /f >nul

call :BANNER

:: select command
call :%CMD% %*
exit /B 0
goto :eof

:: Error handling
:ERR_PRJ_IDE_NOT_DEFINED
echo PRJ_IDE variable not defined
goto :eof

:ERR_IDE_VS_NOT_FOUND
echo IDE version not found, check PRJ_IDE variable and ensure Delphi is installed
goto :eof

:: Available commands
:BANNER
echo %SELF_NAME% v%SELF_VS%
exit /B 0

:INSPECT
echo.
echo    project variables
echo ---------------------------
set PRJ_
echo.
echo    BDS variables
echo ---------------------------
SET BDS
echo delphi_reg=%delphi_reg%
exit /B 0

:INNO
iscc /Qp .\AppSetup.iss /DBuildConfig=Release
exit /B 0

:CLEAN
if (%ARG_CONFIG%)==() (
  set "ARG_CONFIG=Debug"
) 
if (%ARG_OUTPUT%) neq () (
  set "PRJ_OUT_DIR=%ARG_OUTPUT%"
) 
if exist "%BDSbin%" ( 
  call "%BDSbin%\rsvars" > nul
  call msbuild "%PRJ_BUILD_FILE%" /t:Clean /p:Config=%ARG_CONFIG% /p:Platform=Win32
)
exit /B 0

:MAKE
if (%ARG_CONFIG%)==() (
  set "ARG_CONFIG=Debug"
) 
if (%ARG_OUTPUT%) neq () (
  set "PRJ_OUT_DIR=%ARG_OUTPUT%"
) 
if exist "%BDSbin%" ( 
  call "%BDSbin%\rsvars" > nul
  call msbuild "%PRJ_BUILD_FILE%" /t:make /p:Config=%ARG_CONFIG% /p:Platform=Win32
)
exit /B 0

:BUILD
if (%ARG_CONFIG%)==() (
  set "ARG_CONFIG=Debug"
) 
if (%ARG_OUTPUT%) neq () (
  set "PRJ_OUT_DIR=%ARG_OUTPUT%"
) 
if exist "%BDSbin%" ( 
  call "%BDSbin%\rsvars" > nul
  call msbuild "%PRJ_BUILD_FILE%" /t:Build /p:Config=%ARG_CONFIG% /p:Platform=Win32
)
exit /B 0

:START
start "BDS" "%BDSApp%" -idecaption="%PRJ_NAME%" -r"%PRJ_REG_KEY%" "%PRJ_BUILD_FILE%" 
exit /B 0

:ENV
if (%ARG_MODE%)==() (
  set "ARG_MODE=deve"
) 

set /p CONFIRM=setup env to "%ARG_MODE%" in "%PRJ_OUT_DIR%" (y/n)?: 
if /i "%CONFIRM%"=="y" (
  rmdir /s /q "%PRJ_OUT_DIR%"
  robocopy "%PRJ_DIR%\src\runenv\_shared" "%PRJ_OUT_DIR%" /E /NJH /NJS /NFL /NP /NDL
  robocopy "%PRJ_DIR%\src\runenv\%ARG_MODE%" "%PRJ_OUT_DIR%" /E /NJH /NJS /NFL /NP /NDL
  set "DAF_APP_ENV=%ARG_MODE%"
  echo environment established to %ARG_MODE%
) else (
  echo canceled
)
exit /B 0
