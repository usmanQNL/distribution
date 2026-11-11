#!/usr/bin/env bash
# Usage: scripts/test_skill.sh  -> checks the skill itself. Run in CI and before every release of the skill.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; cd "$root"
fail=0
ok()  { echo "ok: $1"; }
bad() { echo "FAIL: $1" >&2; fail=1; }

# 1. Syntax of every shell script
for f in scripts/*.sh test/samples/*/*.sh; do
  [ -f "$f" ] || continue
  bash -n "$f" && ok "syntax $f" || bad "syntax $f"
done

# 2. Detection on each sample app gives the expected answer
expect() { got="$(bash scripts/detect.sh "test/samples/$1" | tr '\n' ' ')"; [ "$got" = "$2" ] && ok "detect $1" || bad "detect $1: got '$got'"; }
expect fastapi     "language=python python_framework=fastapi "
expect flask       "language=python python_framework=flask "
expect streamlit   "language=python python_framework=streamlit "
expect python-uv   "language=python python_framework=none "
expect node        "language=node python_framework=none "

# 3. generate.sh copies every file the generated workflow and scripts need
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
bash scripts/generate.sh "$t" >/dev/null
for f in .github/workflows/release.yml distribution.json distribution.md packaging/app.spec packaging/installer.iss \
         scripts/checksums.sh scripts/sign.sh scripts/make_sh.sh scripts/make_deb.sh scripts/prune_releases.sh scripts/install-linux.sh scripts/uv-deploy.sh; do
  [ -f "$t/$f" ] && ok "generated $f" || bad "generate did not write $f"
done
# every scripts/ path the generated workflow calls must exist in the output
grep -o 'scripts/[A-Za-z_.-]*\.sh' "$t/.github/workflows/release.yml" | sort -u | while read -r s; do
  [ -f "$t/$s" ] && echo "ok: workflow calls $s" || { echo "FAIL: workflow calls missing $s" >&2; exit 1; }
done || fail=1

# 3b. The generated record is a fill-in template: placeholders present, no details from this skill's own project
grep -q '<fill in' "$t/distribution.md" && ok "record has fill-in placeholders" || bad "record has no fill-in placeholders"
grep -qi 'usmanQNL\|QuellDAP\|C:\\' "$t/distribution.md" && bad "record contains this skill's own project details" || ok "record has no project-specific details"
# every script the skill ships is listed in the record
for f in scripts/*.sh; do
  b="$(basename "$f")"; [ "$b" = test_skill.sh ] && continue
  grep -q "$b" "$t/distribution.md" && ok "record lists $b" || bad "record does not list $b"
done

# 4. Copies that must stay identical
for pair in "distribution.md templates/distribution.md" "templates/release.yml .github/workflows/release.yml" \
            "templates/installer.iss packaging/installer.iss"; do
  read -r a b <<< "$pair"
  if cmp -s "$a" "$b"; then ok "in sync: $a = $b"; else bad "out of sync: $a and $b"; fi
done

# 5. Config files parse
python3 -c "import json,sys; [json.load(open(f)) for f in sys.argv[1:]]" distribution.json templates/distribution.json && ok "json parses" || bad "json"
python3 -c "import yaml" 2>/dev/null && python3 -c "import yaml,sys; yaml.safe_load(open('templates/release.yml'))" && ok "workflow yaml parses" || echo "skip: pyyaml not installed"

# 6. Workflow wiring that broke before
python3 - <<'PY' && ok "workflow wiring" || bad "workflow wiring"
import sys, yaml
w = yaml.safe_load(open("templates/release.yml"))
jobs = w["jobs"]
names = lambda j: [s.get("name", "") for s in jobs[j]["steps"]]
errs = []
if not any("Delete build artifacts" in n for n in names("publish")): errs.append("artifact cleanup must be in the publish job")
if any("Delete build artifacts" in n for n in names("prune")): errs.append("artifact cleanup must not be in the prune job")
if jobs["publish"].get("permissions", {}).get("actions") != "write": errs.append("publish needs actions: write")
if "pull_request" not in jobs["publish"]["if"]: errs.append("publish must not run on pull requests")
for e in errs: print("  " + e, file=sys.stderr)
sys.exit(1 if errs else 0)
PY
# Inno resolves Source paths from packaging/, and PyInstaller writes to build/dist
grep -q 'Source: "\.\.\\build\\dist\\app.exe"' templates/installer.iss && ok "installer source path" || bad "installer Source must be ..\\build\\dist\\app.exe"
for f in templates/release.yml scripts/release_local.sh; do
  grep -q -- '--distpath build/dist' "$f" && ok "pyinstaller distpath in $f" || bad "pyinstaller must write to build/dist in $f"
done

[ "$fail" = 0 ] && echo "all checks passed" || { echo "checks failed" >&2; exit 1; }
