@echo off
REM Usage: scripts/release_local.bat  -> runs scripts\release_local.sh on Windows through Git Bash.
REM Needs Git for Windows (provides bash), Python, PyInstaller, Inno Setup 6 (for the installer; installed
REM with winget or choco if missing),
REM and gh (the GitHub CLI; installed with winget or choco if missing) logged in (or GH_TOKEN set). cosign or openssl for signing, per distribution.json.
setlocal

set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH (
  where bash >nul 2>nul && set "BASH=bash"
)
if not defined BASH (
  echo Git Bash not found. Install Git for Windows from https://git-scm.com and run this again.
  exit /b 1
)

where git >nul 2>nul
if errorlevel 1 (
  echo git is not installed. Install Git for Windows from https://git-scm.com, then run this again.
  exit /b 1
)
pushd "%~dp0.."
"%BASH%" scripts/release_local.sh %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
