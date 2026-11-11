#!/usr/bin/env bash
# Usage: generate.sh <project-dir>  -> copies the release workflow, config, guide and agent pointers into the project
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?usage: generate.sh <project-dir>}"
mkdir -p "$target/.github/workflows" "$target/packaging"
cp "$root/templates/release.yml" "$target/.github/workflows/release.yml"
[ -f "$target/distribution.json" ] || cp "$root/templates/distribution.json" "$target/distribution.json"
[ -f "$target/packaging/app.spec" ] || cp "$root/templates/app.spec" "$target/packaging/app.spec"
[ -f "$target/packaging/installer.iss" ] || cp "$root/templates/installer.iss" "$target/packaging/installer.iss"
[ -f "$target/distribution.md" ] || cp "$root/templates/distribution.md" "$target/distribution.md"
mkdir -p "$target/scripts"
for s in checksums.sh sign.sh make_sh.sh make_deb.sh prune_releases.sh install-linux.sh uv-deploy.sh; do
  cp "$root/scripts/$s" "$target/scripts/$s"
done
# Docker: only when the project's distribution.json has targets.docker true. Node projects get the Node file, the rest the Python one.
docker="$(python3 -c "import json,sys; print(json.load(open(sys.argv[1])).get('targets', {}).get('docker', False))" "$target/distribution.json")"
if [ "$docker" = True ]; then
  lang="$(bash "$root/scripts/detect.sh" "$target" | sed -n 's/^language=//p')"
  kind=python; [ "$lang" = node ] && kind=node
  [ -f "$target/Dockerfile" ] || cp "$root/templates/Dockerfile.$kind" "$target/Dockerfile"
  [ -f "$target/.dockerignore" ] || cp "$root/templates/dockerignore" "$target/.dockerignore"
  echo "wrote Dockerfile ($kind) and .dockerignore: fill in its CMD for this project"
fi
for f in AGENTS.md CLAUDE.md GEMINI.md; do
  if [ -f "$target/$f" ]; then
    grep -q "distribution.md" "$target/$f" || printf '\n%s\n' "$(cat "$root/templates/agent-pointers/AGENTS.md")" >> "$target/$f"
  else
    cp "$root/templates/agent-pointers/$f" "$target/$f"
  fi
done
echo "wrote release workflow, distribution.json, packaging/, scripts/, distribution.md and agent pointers to $target"
echo "edit distribution.json: set each target to true only if the user asked for it (run generate.sh again after setting docker to true)"
