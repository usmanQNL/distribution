@echo off
REM Usage: scripts/release_local.bat  -> runs scripts\release_local.sh on Windows through Git Bash.
REM Needs Git for Windows (provides bash), Python, PyInstaller, Inno Setup 6 (for the installer; installed
REM with winget or choco if missing),
REM and gh (the GitHub CLI; installed with winget or choco if missing) logged in (or GH_TOKEN set). cosign or openssl for signing, per distribution.json.
REM Bash is always Git's own bash.exe, found next to git.exe (so per-user installs work). A bare "bash" is never used:
REM on Windows it is often WSL's C:\Windows\System32\bash.exe, which cannot run this script.
setlocal

where git >nul 2>nul
if errorlevel 1 (
  echo git is not installed. Install Git for Windows from https://git-scm.com, then run this again.
  exit /b 1
)

set "BASH="
REM git.exe lives in <Git>\cmd, <Git>\bin or <Git>\mingw64\bin; bash.exe is in <Git>\bin
for /f "delims=" %%G in ('where git 2^>nul') do (
  if not defined BASH if exist "%%~dpG..\bin\bash.exe" for %%B in ("%%~dpG..\bin\bash.exe") do set "BASH=%%~fB"
  if not defined BASH if exist "%%~dpG..\..\bin\bash.exe" for %%B in ("%%~dpG..\..\bin\bash.exe") do set "BASH=%%~fB"
)
REM The usual install folders, in case git.exe on PATH is not Git for Windows
if not defined BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%LocalAppData%\Programs\Git\bin\bash.exe" set "BASH=%LocalAppData%\Programs\Git\bin\bash.exe"
if not defined BASH if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if not defined BASH (
  echo Git Bash was not found next to git.exe. Install Git for Windows from https://git-scm.com and run this again.
  echo A bare "bash" is not used, because on Windows it is often WSL's bash from C:\Windows\System32.
  exit /b 1
)

pushd "%~dp0.."
"%BASH%" scripts/release_local.sh %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
