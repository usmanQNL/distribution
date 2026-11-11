#!/usr/bin/env bash
# Usage: ensure_iscc.sh [--check]  -> prints the path to ISCC.exe (the Inno Setup 6 compiler).
# Used when targets.windows_inno_installer is true. If ISCC is missing on Windows it installs Inno Setup 6
# with winget, or with choco when winget is not there (in GitHub Actions, choco first). --check only looks, never installs.
# Inno Setup runs only on Windows: on Linux or macOS it says so and exits 1.
# Messages go to stderr, so callers can use: iscc="$(bash scripts/ensure_iscc.sh)"
set -euo pipefail
mode="${1:-install}"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) echo "Inno Setup (ISCC) runs only on Windows. Build the installer on a Windows machine with scripts\\release_local.bat, or set build_location to github so the Windows runner builds it." >&2
     exit 1 ;;
esac

find_iscc() {
  local p
  p="$(command -v ISCC.exe 2>/dev/null || command -v iscc 2>/dev/null || true)"
  [ -n "$p" ] && { echo "$p"; return 0; }
  local la=""; [ -n "${LOCALAPPDATA:-}" ] && la="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA")"
  for p in "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" "/c/Program Files/Inno Setup 6/ISCC.exe" "$la/Programs/Inno Setup 6/ISCC.exe"; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

if iscc="$(find_iscc)"; then echo "$iscc"; exit 0; fi

if [ "$mode" = "--check" ]; then
  echo "Inno Setup 6 (ISCC.exe) is not installed. Install it with: winget install --id JRSoftware.InnoSetup -e   (or: choco install innosetup)" >&2
  exit 1
fi

echo "Inno Setup 6 (ISCC.exe) not found; installing it..." >&2
has() { command -v "$1" >/dev/null 2>&1; }
try_winget() { has winget && winget install --id JRSoftware.InnoSetup -e --silent --accept-package-agreements --accept-source-agreements >&2; }
try_choco()  { has choco && choco install innosetup -y --no-progress >&2; }
if [ "${GITHUB_ACTIONS:-}" = true ]; then try_choco || try_winget || true; else try_winget || try_choco || true; fi

if iscc="$(find_iscc)"; then echo "installed Inno Setup: $iscc" >&2; echo "$iscc"; exit 0; fi
echo "Could not install Inno Setup 6. Install it by hand from https://jrsoftware.org/isdl.php (or: winget install --id JRSoftware.InnoSetup -e), then run this again." >&2
exit 1
