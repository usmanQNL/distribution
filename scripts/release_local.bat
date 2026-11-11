@echo off
REM Usage: scripts/release_local.bat  -> runs scripts\release_local.sh on Windows through Git Bash.
REM Needs Git for Windows (provides bash), Python, PyInstaller, Inno Setup 6 (for the installer; installed
REM with winget or choco if missing), and gh logged in (or GH_TOKEN set). cosign or openssl for signing, per distribution.json.
setlocal

where git >nul 2>nul
if errorlevel 1 (
  echo git is not installed. Install Git for Windows from https://git-scm.com, then run this again.
  exit /b 1
)

REM Find Git for Windows' bash.exe. Never use a bare "bash": on Windows it can be WSL's bash in System32.
REM Derive Git's root from git.exe (for example ...\Git\cmd\git.exe -> ...\Git), which works for per-user and system installs.
set "BASH="
for /f "delims=" %%G in ('where git') do (
  if not defined BASH (
    for %%I in ("%%~dpG..") do if exist "%%~fI\bin\bash.exe" set "BASH=%%~fI\bin\bash.exe"
  )
)
if not defined BASH if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH if exist "%LOCALAPPDATA%\Programs\Git\bin\bash.exe" set "BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"
if not defined BASH (
  echo Git Bash not found next to git.exe, in Program Files or in %%LOCALAPPDATA%%\Programs\Git. Install Git for Windows from https://git-scm.com and run this again.
  exit /b 1
)
echo Using bash: %BASH%

pushd "%~dp0.."
"%BASH%" scripts/release_local.sh %*
set "RC=%ERRORLEVEL%"
popd
exit /b %RC%
