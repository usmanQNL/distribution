#!/usr/bin/env bash
# Usage: generate.sh <project-dir>  -> copies the release workflow into the project
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
dest="${1:?usage: generate.sh <project-dir>}/.github/workflows"
mkdir -p "$dest"
cp "$root/templates/release.yml" "$dest/release.yml"
mkdir -p "${1}/packaging"
[ -f "${1}/packaging/app.spec" ] || cp "$root/templates/app.spec" "${1}/packaging/app.spec"
echo "wrote $dest/release.yml"
