#!/usr/bin/env bash
# Usage: generate.sh <project-dir>  -> copies the release workflow and config templates into the project
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?usage: generate.sh <project-dir>}"
mkdir -p "$target/.github/workflows" "$target/packaging"
cp "$root/templates/release.yml" "$target/.github/workflows/release.yml"
[ -f "$target/distribution.json" ] || cp "$root/templates/distribution.json" "$target/distribution.json"
[ -f "$target/packaging/app.spec" ] || cp "$root/templates/app.spec" "$target/packaging/app.spec"
[ -f "$target/packaging/installer.iss" ] || cp "$root/templates/installer.iss" "$target/packaging/installer.iss"
echo "wrote release workflow, distribution.json, packaging/ templates to $target"
echo "edit distribution.json: set each target to true only if the user asked for it"
