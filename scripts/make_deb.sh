#!/usr/bin/env bash
# Usage: make_deb.sh <src-dir> <name> <version> <out-dir>  -> <out-dir>/<name>-<version>-linux-amd64.deb (needs dpkg-deb)
set -euo pipefail
src="${1:?}"; name="${2:?}"; ver="${3:?}"; out="${4:?}"
root="$(mktemp -d)/${name}_${ver}"
mkdir -p "$root/DEBIAN" "$root/opt/$name" "$root/usr/bin"
cp -r "$src"/. "$root/opt/$name/"
ln -sf "/opt/$name/$name" "$root/usr/bin/$name"
cat > "$root/DEBIAN/control" <<CTRL
Package: $name
Version: $ver
Architecture: amd64
Maintainer: release-bot <noreply@example.com>
Description: $name release build
CTRL
mkdir -p "$out"
dpkg-deb --build "$root" "$out/${name}-${ver}-linux-amd64.deb"
