#!/usr/bin/env bash
# Usage: release_local.sh  -> build, checksum, sign and publish on THIS machine (build_location = "local").
# On Linux, also publishes <app_name>-<version>-linux-install.sh (installs the .deb or .sh for the user, or system-wide with --system).
# Needs: gh (installed by scripts/ensure_gh.sh if missing, then logged in, or GH_TOKEN set), python3, pyinstaller (for exe/linux binary), zip (node), dpkg-deb (deb), Inno Setup 6 (installer, Windows;
#        installed with winget or choco if missing), cosign (cosign signing) or openssl (ed25519), and gh authenticated with the releases repo, or GH_TOKEN set.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; cd "$root"

# Preflight: git must be installed, and gh must be logged in to the releases repo
if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed. Install it first (see distribution.md, 'Git on the local machine'), then run this again." >&2
  exit 1
fi
# The GitHub CLI publishes the release: find it, or install it (winget/choco, brew, apt/dnf/pacman/zypper)
gh_bin="$(bash scripts/ensure_gh.sh)" || { echo "stopping: the GitHub CLI (gh) is needed to publish the release" >&2; exit 1; }
PATH="$(dirname "$gh_bin"):$PATH"   # a fresh install may not be on this shell's PATH yet
if [ -z "${GH_TOKEN:-}" ] && ! gh auth status >/dev/null 2>&1; then
  if [ -t 0 ] && [ -t 1 ]; then
    echo "gh is not logged in. Starting: gh auth login (choose GitHub.com, HTTPS, Login with a web browser)" >&2
    gh auth login --hostname github.com --git-protocol https --web && gh auth setup-git \
      || { echo "gh login did not finish. Run: gh auth login (see distribution.md), then run this again." >&2; exit 1; }
  else
    echo "gh is not logged in. Run: gh auth login (see distribution.md), or set GH_TOKEN, then run this again." >&2
    exit 1
  fi
fi
cfg() { python3 -c "import json,sys;d=json.load(open('distribution.json'));print(eval(sys.argv[1]))" "$1"; }
flag() { [ "$(cfg "d['targets']['$1']")" = "True" ]; }
signing="$(cfg "d.get('signing','cosign')")"
releases="${RELEASES_REPO:-$(cfg "d.get('releases_repo','')")}"
bundle_frontend="$(cfg "d.get('bundle_frontend',False)")"
frontend_dir="$(cfg "d.get('frontend_dir') or '.'")"
frontend_dist="$(cfg "d.get('frontend_dist') or 'dist'")"
# Release name: the first part of every release file name (app_name in distribution.json)
name="$(cfg "d.get('app_name') or 'app'")"
[[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || { echo "app_name '$name' may use only letters, digits, '.', '_' and '-' (no spaces), starting with a letter or digit" >&2; exit 1; }
major="$(tr -d '[:space:]' < VERSION)"; stamp="$(date -u +%Y%m%d_%H%M)"
ver="v$major.$stamp"              # release tag, same scheme as the workflow
pkgver="$major.${stamp/_/}"       # package version for .deb, .sh and the installer
out="$root/release"; rm -rf "$out"; mkdir -p "$out"
# Ed25519 signing: check RELEASE_SIGNING_KEY now, before the long build (the key text, or a path such as root-private.pem)
if [ "$signing" = ed25519 ]; then
  pubkey=""; [ -f packaging/keys/release-signing-public.pem ] && pubkey=packaging/keys/release-signing-public.pem
  bash scripts/sign.sh - check-key $pubkey || { echo "stopping: set RELEASE_SIGNING_KEY first, for example: export RELEASE_SIGNING_KEY=\"\$HOME/keys/root-private.pem\"" >&2; exit 1; }
fi
# Inno Setup installer: find ISCC now, before the long build, and install Inno Setup 6 if it is missing (Windows only)
iscc=""
if flag windows_inno_installer; then
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) iscc="$(bash scripts/ensure_iscc.sh)" || { echo "stopping: the Windows installer is selected but Inno Setup is not available" >&2; exit 1; } ;;
    *) echo "note: the Windows installer is selected, but Inno Setup runs only on Windows; this run skips it. Run scripts\\release_local.bat on Windows for it." >&2 ;;
  esac
fi
if [ "$(cfg "d['targets'].get('docker',False)")" = "True" ]; then
  echo "note: the Docker image is built and pushed to GHCR only by the GitHub workflow; locally, run: docker build -t ${name,,}:$pkgver ." >&2
fi

# 0. Settings template: the project's .env.example, or its .env with every value removed (never the real .env).
#    It goes in the release as <app_name>-<version>-env.example, and next to the program in the installer and Linux packages.
rm -rf build/env
bash scripts/env_example.sh . build/env/.env.example
if [ -f build/env/.env.example ]; then cp build/env/.env.example "$out/$name-$pkgver-env.example"; fi

# 1. Frontend first, so PyInstaller can bundle it (bundle_frontend) and the SPA zip can ship it
if { flag node_spa_zip || [ "$bundle_frontend" = "True" ]; } && [ -f "$frontend_dir/package.json" ]; then
  (cd "$frontend_dir" && npm ci && npm run build)
  if flag node_spa_zip; then
    (cd "$frontend_dir/$frontend_dist" && zip -qr "$out/$name-$pkgver-frontend.zip" .)
  fi
fi

# 2. PyInstaller (only when a packaged target is selected). Output goes to build/dist, apart from the frontend's dist/.
if flag windows_exe || flag windows_inno_installer || flag linux_sh || flag linux_deb; then
  pyinstaller --noconfirm --distpath build/dist --workpath build/work packaging/app.spec
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) if flag windows_exe; then cp "build/dist/$name.exe" "$out/$name-$pkgver-windows.exe"; fi ;;
  esac
fi

# 3. Linux installers (built from build/dist/)
if [ "$(uname -s)" = "Linux" ] && { flag linux_sh || flag linux_deb; }; then
  src=build/dist; [ -d "build/dist/$name" ] && src="build/dist/$name"
  if [ -f build/env/.env.example ]; then cp build/env/.env.example "$src/.env.example"; fi
  if flag linux_sh; then bash scripts/make_sh.sh "$src" "$out/$name-$pkgver-linux.sh" "$name"; fi
  if flag linux_deb; then bash scripts/make_deb.sh "$src" "$name" "$pkgver" "$out"; fi
  # Install script for Linux users, published alongside the installers
  sed "s/^APP=app\$/APP=$name/" "$root/scripts/install-linux.sh" > "$out/$name-$pkgver-linux-install.sh"
fi

# 4. Windows Inno Setup (ISCC found or installed in the preflight above; Windows only). It writes straight into release/.
if [ -n "$iscc" ]; then
  # Git Bash rewrites arguments that start with / into paths, which breaks /D; turn that off for ISCC
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' "$iscc" "/DMyAppName=$name" "/DMyAppVersion=$pkgver" packaging/installer.iss
fi

# 4b. uv deploy bundle: the source at this commit, with scripts/uv-deploy.sh inside
if flag uv_deploy; then
  git archive --format=tar.gz --prefix="$name-$pkgver/" -o "$out/$name-$pkgver-uv.tar.gz" HEAD
fi

# 5. Checksums, then signatures
[ -n "$(find "$out" -maxdepth 1 -type f ! -name '*-env.example' -print -quit)" ] || { echo "nothing selected to build" >&2; exit 1; }
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
notes="$(echo "Released locally from $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"; bash scripts/env_example.sh --notes "$out")"
gh release create "$ver" "$out"/* --repo "$releases" --title "$ver" --notes "$notes"
echo "published $ver to $releases"
