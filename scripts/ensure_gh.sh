#!/usr/bin/env bash
# Usage: ensure_gh.sh [--check]  -> prints the path to gh (the GitHub CLI), installing it first if it is missing.
# Used by local releases (build_location = "local"), which publish with gh. Installs with winget or choco on Windows,
# brew on macOS, and on Linux the official GitHub CLI apt repo (Debian, Ubuntu) or dnf, pacman or zypper.
# --check only looks, never installs. Logging in is separate: release_local.sh checks gh auth status after this.
# Messages go to stderr, so callers can use: gh_bin="$(bash scripts/ensure_gh.sh)"
set -euo pipefail
mode="${1:-install}"
has() { command -v "$1" >/dev/null 2>&1; }

find_gh() {
  local p
  p="$(command -v gh 2>/dev/null || command -v gh.exe 2>/dev/null || true)"
  [ -n "$p" ] && { echo "$p"; return 0; }
  local la=""; [ -n "${LOCALAPPDATA:-}" ] && la="$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA")"
  for p in "/c/Program Files/GitHub CLI/gh.exe" "/c/Program Files (x86)/GitHub CLI/gh.exe" "$la/Programs/GitHub CLI/gh.exe" \
           /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh; do
    [ -f "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

if gh_bin="$(find_gh)"; then echo "$gh_bin"; exit 0; fi

os="$(uname -s)"
hint="Install it from https://cli.github.com (Windows: winget install --id GitHub.cli -e; macOS: brew install gh; Debian or Ubuntu: see https://github.com/cli/cli/blob/trunk/docs/install_linux.md)."
if [ "$mode" = "--check" ]; then
  echo "The GitHub CLI (gh) is not installed. $hint" >&2
  exit 1
fi

echo "The GitHub CLI (gh) is not installed; installing it..." >&2
sudo_=""; [ "$(id -u 2>/dev/null || echo 0)" != 0 ] && has sudo && sudo_="sudo"
case "$os" in
  MINGW*|MSYS*|CYGWIN*)
    { has winget && winget install --id GitHub.cli -e --silent --accept-package-agreements --accept-source-agreements >&2; } \
      || { has choco && choco install gh -y --no-progress >&2; } || true ;;
  Darwin)
    if has brew; then brew install gh >&2 || true
    else echo "Homebrew is not installed, so gh cannot be installed automatically. Download the macOS installer from https://cli.github.com, or install Homebrew from https://brew.sh first." >&2; exit 1; fi ;;
  Linux)
    if has apt-get; then
      # The official GitHub CLI apt repository, as documented at cli.github.com
      { $sudo_ mkdir -p -m 755 /etc/apt/keyrings \
        && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $sudo_ tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null \
        && $sudo_ chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $sudo_ tee /etc/apt/sources.list.d/github-cli.list >/dev/null \
        && $sudo_ apt-get update >&2 && $sudo_ apt-get install -y gh >&2; } || true
    elif has dnf; then $sudo_ dnf install -y gh >&2 || true
    elif has pacman; then $sudo_ pacman -S --noconfirm github-cli >&2 || true
    elif has zypper; then $sudo_ zypper --non-interactive install gh >&2 || true
    fi ;;
esac

if gh_bin="$(find_gh)"; then echo "installed the GitHub CLI: $gh_bin" >&2; echo "$gh_bin"; exit 0; fi
echo "Could not install the GitHub CLI (gh) automatically. $hint Then run this again." >&2
exit 1
