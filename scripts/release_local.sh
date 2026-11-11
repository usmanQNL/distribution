#!/usr/bin/env bash
# Usage: release_local.sh  -> build, checksum, sign and publish on THIS machine (build_location = "local").
# On Linux, also publishes app-<version>-linux-install.sh (installs the .deb or .sh for the user, or system-wide with --system).
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
bundle_frontend="$(cfg "d.get('bundle_frontend',False)")"
frontend_dir="$(cfg "d.get('frontend_dir') or '.'")"
frontend_dist="$(cfg "d.get('frontend_dist') or 'dist'")"
major="$(tr -d '[:space:]' < VERSION)"; stamp="$(date -u +%Y%m%d_%H%M)"
ver="v$major.$stamp"              # release tag, same scheme as the workflow
pkgver="$major.${stamp/_/}"       # package version for .deb, .sh and the installer
out="$root/release"; rm -rf "$out"; mkdir -p "$out"
if [ "$(cfg "d['targets'].get('docker',False)")" = "True" ]; then
  echo "note: the Docker image is built and pushed to GHCR only by the GitHub workflow; locally, run: docker build -t app:$pkgver ." >&2
fi

# 1. Frontend first, so PyInstaller can bundle it (bundle_frontend) and the SPA zip can ship it
if { flag node_spa_zip || [ "$bundle_frontend" = "True" ]; } && [ -f "$frontend_dir/package.json" ]; then
  (cd "$frontend_dir" && npm ci && npm run build)
  if flag node_spa_zip; then
    (cd "$frontend_dir/$frontend_dist" && zip -qr "$out/app-$pkgver-frontend.zip" .)
  fi
fi

# 2. PyInstaller (only when a packaged target is selected). Output goes to build/dist, apart from the frontend's dist/.
if flag windows_exe || flag windows_inno_installer || flag linux_sh || flag linux_deb; then
  pyinstaller --noconfirm --distpath build/dist --workpath build/work packaging/app.spec
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) if flag windows_exe; then cp build/dist/app.exe "$out/app-$pkgver-windows.exe"; fi ;;
  esac
fi

# 3. Linux installers (built from build/dist/)
if [ "$(uname -s)" = "Linux" ] && { flag linux_sh || flag linux_deb; }; then
  src=build/dist; [ -d build/dist/app ] && src=build/dist/app
  if flag linux_sh; then bash scripts/make_sh.sh "$src" "$out/app-$pkgver-linux.sh"; fi
  if flag linux_deb; then bash scripts/make_deb.sh "$src" app "$pkgver" "$out"; fi
  # Install script for Linux users, published alongside the installers
  cp "$root/scripts/install-linux.sh" "$out/app-$pkgver-linux-install.sh"
fi

# 4. Windows Inno Setup (needs Inno Setup 6 installed; run on Windows). It writes straight into release/.
if flag windows_inno_installer; then
  case "$(uname -s)" in
    # Git Bash rewrites arguments that start with / into paths, which breaks /D; turn that off for ISCC
    MINGW*|MSYS*|CYGWIN*) MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" "/DMyAppVersion=$pkgver" packaging/installer.iss ;;
    *) echo "skipping the Windows installer: build it on Windows" >&2 ;;
  esac
fi

# 4b. uv deploy bundle: the source at this commit, with scripts/uv-deploy.sh inside
if flag uv_deploy; then
  git archive --format=tar.gz --prefix="app-$pkgver/" -o "$out/app-$pkgver-uv.tar.gz" HEAD
fi

# 5. Checksums, then signatures
[ -n "$(ls -A "$out")" ] || { echo "nothing selected to build" >&2; exit 1; }
bash scripts/checksums.sh "$out"
case "$signing" in
  cosign) bash scripts/sign.sh "$out" cosign-sums ;;  # one browser sign-in per run
  cosign-all) bash scripts/sign.sh "$out" cosign ;;   # one sign-in per file
  ed25519)
    if [ -f packaging/keys/release-signing-public.pem ]; then
      bash scripts/sign.sh "$out" ed25519 packaging/keys/release-signing-public.pem
    else
      bash scripts/sign.sh "$out" ed25519
    fi ;;
esac

# 6. Publish
[ -n "$releases" ] || { echo "set releases_repo in distribution.json or RELEASES_REPO" >&2; exit 1; }
# Two runs in the same minute would share a tag; keep the second one unique
if gh release view "$ver" --repo "$releases" >/dev/null 2>&1; then ver="$ver.$(date -u +%S)"; fi
gh release create "$ver" "$out"/* --repo "$releases" --title "$ver" --notes "Released locally from $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "published $ver to $releases"
