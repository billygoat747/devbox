@echo off
REM Reset ephemeral sandbox dirs to a fresh state.
REM Removes everything inside workspace\ and .opencode-state\ except .gitkeep.
REM Usage: clean.bat [--force]
REM   Without --force, asks for confirmation before deleting.
setlocal EnableDelayedExpansion

set "FORCE=0"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--force" set "FORCE=1"
if /i "%~1"=="-f" set "FORCE=1"
if /i "%~1"=="--yes" set "FORCE=1"
if /i "%~1"=="-y" set "FORCE=1"
if /i "%~1"=="/f" set "FORCE=1"
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-h" goto usage
if /i "%~1"=="/?" goto usage
if /i not "%~1"=="--force" if /i not "%~1"=="-f" if /i not "%~1"=="--yes" if /i not "%~1"=="-y" if /i not "%~1"=="/f" (
  echo Unknown argument: %~1 ^(try --help^) 1>&2
  exit /b 1
)
shift
goto parse_args

:usage
echo Usage: %~nx0 [--force]
echo   Without --force, asks for confirmation before deleting.
exit /b 0

:args_done

REM Script directory without trailing backslash.
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

REM Warn if the sandbox container is still running against these bind mounts.
set "RUNNING="
where docker >nul 2>nul
if %ERRORLEVEL%==0 (
  for /f "delims=" %%i in ('docker compose --project-directory "%ROOT%" ps -q 2^>nul') do set "RUNNING=%%i"
)
if defined RUNNING (
  echo WARNING: agent-sandbox container is running. Stop it first to avoid surprises:
  echo   docker compose --project-directory "%ROOT%" down
  if "%FORCE%"=="0" (
    set "ANSWER="
    set /p ANSWER="Continue anyway? [y/N] "
    if /i not "!ANSWER!"=="y" if /i not "!ANSWER!"=="yes" (
      echo Aborted.
      exit /b 1
    )
  )
)

if "%FORCE%"=="0" (
  echo This will delete ALL contents of:
  echo   %ROOT%\workspace ^(except .gitkeep^)
  echo   %ROOT%\.opencode-state ^(except .gitkeep^)
  set "ANSWER="
  set /p ANSWER="Continue? [y/N] "
  if /i not "!ANSWER!"=="y" if /i not "!ANSWER!"=="yes" (
    echo Aborted.
    exit /b 1
  )
)

call :CleanDir "%ROOT%\workspace"
call :CleanDir "%ROOT%\.opencode-state"

echo Done. Fresh workspace + state ready.
exit /b 0

:CleanDir
set "DIR=%~1"
if not exist "%DIR%\" mkdir "%DIR%"
REM Delete everything one level deep except .gitkeep (includes hidden files).
for /f "delims=" %%N in ('dir /a /b "%DIR%" 2^>nul') do (
  if /i not "%%N"==".gitkeep" (
    if exist "%DIR%\%%N\" (
      rmdir /s /q "%DIR%\%%N"
    ) else (
      del /f /q /a "%DIR%\%%N" >nul 2>&1
    )
  )
)
REM Keep the dir tracked in git.
if not exist "%DIR%\.gitkeep" type nul > "%DIR%\.gitkeep"
echo Cleaned %DIR%
exit /b 0
