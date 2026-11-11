#!/usr/bin/env bash
# Installs the app for the current user on Linux. Run from the folder with the release files:
#   bash app-<version>-linux-install.sh            (installs to ~/.local/share/app, command in ~/.local/bin)
#   sudo bash app-<version>-linux-install.sh --system   (installs to /opt/app, command in /usr/local/bin)
# Uses the .deb if present (system install with dpkg), otherwise the self-extracting .sh.
set -euo pipefail
APP=app
here="$(cd "$(dirname "$0")" && pwd)"
mode="${1:-user}"

deb="$(ls "$here"/${APP}-*-linux-amd64.deb 2>/dev/null | head -n1 || true)"
sh_installer="$(ls "$here"/${APP}-*-linux.sh 2>/dev/null | head -n1 || true)"

if [ "$mode" = "--system" ]; then
  if [ -n "$deb" ] && command -v dpkg >/dev/null 2>&1; then
    sudo dpkg -i "$deb"
    echo "installed $APP with dpkg"
    exit 0
  fi
  [ -n "$sh_installer" ] || { echo "no installer found next to this script" >&2; exit 1; }
  dest=/opt/$APP
  sudo mkdir -p "$dest"
  sudo bash "$sh_installer" "$dest"
  sudo ln -sf "$dest/$APP" /usr/local/bin/$APP
  echo "installed $APP to $dest (command: $APP)"
else
  [ -n "$sh_installer" ] || { echo "no installer found next to this script" >&2; exit 1; }
  dest="$HOME/.local/share/$APP"
  bash "$sh_installer" "$dest"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$dest/$APP" "$HOME/.local/bin/$APP"
  echo "installed $APP to $dest (command: $APP, make sure ~/.local/bin is on PATH)"
fi
