#!/usr/bin/env bash
# Usage: release_local.sh  -> build, checksum, sign and publish on THIS machine (build_location = "local").
# On Linux, also publishes install-linux.sh (installs the .deb or .sh for the user, or system-wide with --system).
# Needs: python3, pyinstaller (for exe/linux binary), zip (node), dpkg-deb (deb), cosign (cosign signing) or
#        openssl (ed25519), and gh authenticated with the releases repo, or GH_TOKEN set.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; cd "$root"

# Preflight: git must be installed, and gh must be logged in to the releases repo
if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed. Install it first (see distribution.md, 'Git on the local machine'), then run this again." >&2
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "gh is not logged in. Run: gh auth login (see distribution.md), then run this again." >&2
  exit 1
fi
cfg() { python3 -c "import json,sys;d=json.load(open('distribution.json'));print(eval(sys.argv[1]))" "$1"; }
flag() { [ "$(cfg "d['targets']['$1']")" = "True" ]; }
signing="$(cfg "d.get('signing','cosign')")"
releases="${RELEASES_REPO:-$(cfg "d.get('releases_repo','')")}"
ver="v$(cat VERSION).$(date -u +%Y%m%d_%H%M)"
out="$root/release"; rm -rf "$out"; mkdir -p "$out"

# 1. Node SPA
if flag node_spa_zip && [ -f package.json ]; then
  npm ci && npm run build && (cd dist && zip -qr "$out/frontend-$(uname -s | tr '[:upper:]' '[:lower:]').zip" .)
fi

# 2. PyInstaller (only when a packaged target is selected)
if flag windows_exe || flag linux_sh || flag linux_deb; then
  pyinstaller --noconfirm packaging/app.spec
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) flag windows_exe && cp dist/app.exe "$out/" ;;
    *) { flag linux_sh || flag linux_deb; } && cp dist/app "$out/" ;;
  esac
fi

# 3. Linux installers (built from dist/)
if [ "$(uname -s)" = "Linux" ]; then
  src=dist; [ -d dist/app ] && src=dist/app
  flag linux_sh && bash scripts/make_sh.sh "$src" "$out/app-$(cat VERSION)-linux.sh"
  flag linux_deb && bash scripts/make_deb.sh "$src" app "$(cat VERSION)" "$out"
  [ -f "$out/app" ] && { flag linux_sh || flag linux_deb; } && rm -f "$out/app"
  # Install script for Linux users, published alongside the installers
  { flag linux_sh || flag linux_deb; } && cp "$root/scripts/install-linux.sh" "$out/install-linux.sh"
fi

# 4. Windows Inno Setup (needs Inno Setup 6 installed; run on Windows)
if flag windows_inno_installer; then
  "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" packaging/installer.iss && mv release/*-setup.exe "$out/" 2>/dev/null || true
fi

# 5. Checksums, then signatures
[ -n "$(ls -A "$out")" ] || { echo "nothing selected to build" >&2; exit 1; }
bash scripts/checksums.sh "$out"
case "$signing" in
  cosign) bash scripts/sign.sh "$out" cosign-sums ;;  # one browser sign-in per run
  cosign-all) bash scripts/sign.sh "$out" cosign ;;   # one sign-in per file
  ed25519) bash scripts/sign.sh "$out" ed25519 $( [ -f packaging/keys/release-signing-public.pem ] && echo packaging/keys/release-signing-public.pem ) ;;
esac

# 6. Publish
[ -n "$releases" ] || { echo "set releases_repo in distribution.json or RELEASES_REPO" >&2; exit 1; }
gh release create "$ver" "$out"/* --repo "$releases" --title "$ver" --notes "Released locally from $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "published $ver to $releases"
