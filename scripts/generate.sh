#!/usr/bin/env bash
# Usage: generate.sh <project-dir>  -> copies the release workflow, config, guide and agent pointers into the project
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
target="${1:?usage: generate.sh <project-dir>}"
mkdir -p "$target/.github/workflows" "$target/packaging"
cp "$root/templates/release.yml" "$target/.github/workflows/release.yml"
if [ ! -f "$target/distribution.json" ]; then
  cp "$root/templates/distribution.json" "$target/distribution.json"
  # app_name (the release name) defaults to the project folder name; the setup question can change it
  name="$(basename "$(cd "$target" && pwd)" | tr -c 'A-Za-z0-9._\n-' '-' | sed 's/^[-._]*//')"
  if [ -n "$name" ]; then
    python3 -c 'import json,sys;p=sys.argv[1];d=json.load(open(p));d["app_name"]=sys.argv[2];open(p,"w").write(json.dumps(d,indent=2)+"\n")' \
      "$target/distribution.json" "$name"
  fi
fi
[ -f "$target/packaging/app.spec" ] || cp "$root/templates/app.spec" "$target/packaging/app.spec"
[ -f "$target/packaging/installer.iss" ] || cp "$root/templates/installer.iss" "$target/packaging/installer.iss"
# Loads the .env next to the built program; packaging/app.spec picks it up as a runtime hook
cp "$root/templates/env_hook.py" "$target/packaging/env_hook.py"
[ -f "$target/distribution.md" ] || cp "$root/templates/distribution.md" "$target/distribution.md"
mkdir -p "$target/scripts"
for s in checksums.sh sign.sh env_example.sh make_sh.sh make_deb.sh prune_releases.sh install-linux.sh uv-deploy.sh ensure_iscc.sh ensure_gh.sh; do
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
# .env: releases ship a settings template, never the real file. With only a .env, write .env.example from it,
# values removed, for the user to check and commit. Keep the real .env out of git.
if [ "$(bash "$root/scripts/detect.sh" "$target" | sed -n 's/^uses_env=//p')" = yes ]; then
  if [ -f "$target/.env" ] && [ ! -f "$target/.env.example" ] && [ ! -f "$target/.env.sample" ] && [ ! -f "$target/.env.template" ]; then
    bash "$root/scripts/env_example.sh" "$target" "$target/.env.example" >/dev/null
    echo "wrote .env.example from .env with every value removed: check it, then commit it (releases ship it)"
  fi
  if [ -f "$target/.env" ] && git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$target" ls-files --error-unmatch .env >/dev/null 2>&1; then
      echo "warning: .env is committed to git. Remove it (git rm --cached .env) and rotate any secret in it." >&2
    elif ! git -C "$target" check-ignore -q .env; then
      if [ -s "$target/.gitignore" ] && [ -n "$(tail -c1 "$target/.gitignore")" ]; then echo >> "$target/.gitignore"; fi
      printf '.env\n' >> "$target/.gitignore"; echo "added .env to .gitignore"
    fi
  fi
  [ -f "$target/.env.example" ] || [ -f "$target/.env.sample" ] || [ -f "$target/.env.template" ] \
    || echo "the app reads a .env, but there is no .env.example: write one listing the variables it needs (names only), so releases ship it"
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
