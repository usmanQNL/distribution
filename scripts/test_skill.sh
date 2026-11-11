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
         scripts/checksums.sh scripts/sign.sh scripts/make_sh.sh scripts/make_deb.sh scripts/prune_releases.sh scripts/install-linux.sh scripts/uv-deploy.sh scripts/ensure_iscc.sh scripts/ensure_gh.sh; do
  [ -f "$t/$f" ] && ok "generated $f" || bad "generate did not write $f"
done
# every scripts/ path the generated workflow calls must exist in the output
grep -o 'scripts/[A-Za-z_.-]*\.sh' "$t/.github/workflows/release.yml" | sort -u | while read -r s; do
  [ -f "$t/$s" ] && echo "ok: workflow calls $s" || { echo "FAIL: workflow calls missing $s" >&2; exit 1; }
done || fail=1

[ -f "$t/Dockerfile" ] && bad "generate wrote a Dockerfile with targets.docker false" || ok "no Dockerfile when docker is off"

# 3a. With targets.docker true, generate.sh writes the Dockerfile that fits the language, and .dockerignore
dock() { # dock <sample> <template>
  d="$t/docker-$1"; cp -r "test/samples/$1" "$d"; printf '{"targets":{"docker":true}}' > "$d/distribution.json"
  bash scripts/generate.sh "$d" >/dev/null
  if cmp -s "$d/Dockerfile" "templates/$2" && cmp -s "$d/.dockerignore" templates/dockerignore; then ok "docker $1 gets $2"; else bad "docker $1 should get $2 and .dockerignore"; fi
}
dock flask Dockerfile.python
dock fastapi Dockerfile.python
dock python-uv Dockerfile.python
dock node Dockerfile.node

# 3b. The generated record is a fill-in template: placeholders present, no details from this skill's own project
grep -q '<fill in' "$t/distribution.md" && ok "record has fill-in placeholders" || bad "record has no fill-in placeholders"
grep -qi 'usmanQNL\|QuellDAP\|C:\\' "$t/distribution.md" && bad "record contains this skill's own project details" || ok "record has no project-specific details"
# every script the skill ships is listed in the record
for f in scripts/*.sh; do
  b="$(basename "$f")"; case "$b" in test_skill.sh|check_dco.sh) continue ;; esac  # repo-only, not shipped
  grep -q "$b" "$t/distribution.md" && ok "record lists $b" || bad "record does not list $b"
done

# 4. Copies that must stay identical
for pair in "distribution.md templates/distribution.md" "templates/release.yml .github/workflows/release.yml" \
            "templates/installer.iss packaging/installer.iss" "templates/dockerignore .dockerignore"; do
  read -r a b <<< "$pair"
  if cmp -s "$a" "$b"; then ok "in sync: $a = $b"; else bad "out of sync: $a and $b"; fi
done

# This repo's own Dockerfile is the Python template with only CMD filled in
if cmp -s <(grep -v '^CMD ' Dockerfile) <(grep -v '^CMD ' templates/Dockerfile.python); then ok "in sync: Dockerfile = templates/Dockerfile.python (apart from CMD)"; else bad "out of sync: Dockerfile and templates/Dockerfile.python"; fi

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
d = jobs.get("docker")
if not d: errs.append("docker job is missing")
else:
    if "docker" not in jobs["publish"]["needs"]: errs.append("publish must wait for the docker job")
    if "skipped" not in jobs["publish"]["if"]: errs.append("publish must still run when the docker job is skipped")
    if d.get("permissions", {}).get("packages") != "write": errs.append("docker needs packages: write")
    for st in d["steps"]:
        if "push" in str(st.get("run", "")).lower() and "pull_request" not in str(st.get("if", "")): errs.append("docker push must not run on pull requests")
for e in errs: print("  " + e, file=sys.stderr)
sys.exit(1 if errs else 0)
PY
# Inno resolves Source paths from packaging/, and PyInstaller writes to build/dist
grep -q 'Source: "\.\.\\build\\dist\\{#MyAppName}\.exe"' templates/installer.iss && ok "installer source path" || bad "installer Source must be ..\\build\\dist\\{#MyAppName}.exe"

# 7. The release name (app_name) is used everywhere a release file or the build is named
python3 -c "import json,sys;d=json.load(open(sys.argv[1]));sys.exit(0 if d['app_name']==sys.argv[2] else 1)" "$t/distribution.json" "$(basename "$t")" \
  && ok "generate sets app_name to the project folder name" || bad "generate must set app_name to the project folder name"
for f in templates/release.yml scripts/release_local.sh; do
  if grep -nE '(release|out)/app-|"app-\$|app:\$pkgver|build/dist/app|make_deb\.sh "\$[A-Za-z]+" app ' "$f"; then bad "$f still hard-codes app in a release name"; else ok "no hard-coded app names in $f"; fi
done
grep -q '"\$APP_NAME-\$PKGVER-"\*)' templates/release.yml && ok "name check uses app_name" || bad "the name check must use \$APP_NAME-\$PKGVER-"
grep -q '/DMyAppName=' templates/release.yml && grep -q '/DMyAppName=' scripts/release_local.sh && ok "installer gets MyAppName" || bad "ISCC must get /DMyAppName"
grep -q 'scripts/ensure_iscc.sh' templates/release.yml && grep -q 'scripts/ensure_iscc.sh' scripts/release_local.sh && ok "ISCC is found or installed before the installer build" || bad "the workflow and release_local.sh must call scripts/ensure_iscc.sh"
if [ "$(uname -s)" = Linux ]; then
  if bash scripts/ensure_iscc.sh 2>"$t/iscc.err"; then bad "ensure_iscc.sh must fail off Windows"; else grep -q 'only on Windows' "$t/iscc.err" && ok "ensure_iscc.sh explains Inno Setup is Windows-only" || bad "ensure_iscc.sh must explain it needs Windows"; fi
fi
grep -q 'scripts/ensure_gh.sh' scripts/release_local.sh && ok "release_local.sh finds or installs gh" || bad "release_local.sh must call scripts/ensure_gh.sh"
if command -v gh >/dev/null 2>&1; then [ "$(bash scripts/ensure_gh.sh --check)" = "$(command -v gh)" ] && ok "ensure_gh.sh --check finds gh" || bad "ensure_gh.sh --check must print the gh path"; fi
if grep -qiE 'where bash|set "BASH=bash"' scripts/release_local.bat; then bad "release_local.bat must not fall back to a bare bash (WSL)"; else ok "release_local.bat never uses a bare bash"; fi
grep -q "where git" scripts/release_local.bat && grep -q 'bin\\bash.exe' scripts/release_local.bat && ok "release_local.bat finds Git's bash.exe from git.exe" || bad "release_local.bat must find bash.exe next to git.exe"
# RELEASE_SIGNING_KEY is checked before the build, and sign.sh check-key catches a missing, wrong or mismatched key
grep -q 'check-key' templates/release.yml && grep -q 'check-key' scripts/release_local.sh && ok "signing key is checked before the build" || bad "the workflow and release_local.sh must run sign.sh check-key"
k="$t/keys"; mkdir -p "$k"
openssl genpkey -algorithm ed25519 -out "$k/a-private.pem" 2>/dev/null && openssl pkey -in "$k/a-private.pem" -pubout -out "$k/a-public.pem"
openssl genpkey -algorithm ed25519 -out "$k/b-private.pem" 2>/dev/null
( unset RELEASE_SIGNING_KEY; bash scripts/sign.sh - check-key >/dev/null 2>&1 ) && bad "check-key must fail when RELEASE_SIGNING_KEY is unset" || ok "check-key fails when the key is unset"
RELEASE_SIGNING_KEY="$(cat "$k/a-private.pem")" bash scripts/sign.sh - check-key "$k/a-public.pem" >/dev/null && ok "check-key accepts the key contents" || bad "check-key must accept the PEM contents"
RELEASE_SIGNING_KEY="$k/a-private.pem" bash scripts/sign.sh - check-key "$k/a-public.pem" >/dev/null && ok "check-key accepts a key file path" || bad "check-key must accept a path"
RELEASE_SIGNING_KEY="$k/b-private.pem" bash scripts/sign.sh - check-key "$k/a-public.pem" >/dev/null 2>&1 && bad "check-key must reject a key that does not match the public key" || ok "check-key rejects a mismatched key"
RELEASE_SIGNING_KEY="not a key" bash scripts/sign.sh - check-key >/dev/null 2>&1 && bad "check-key must reject text that is not a key" || ok "check-key rejects text that is not a key"
s="$t/signme"; mkdir -p "$s"; echo hi > "$s/a.txt"
RELEASE_SIGNING_KEY="$k/a-private.pem" bash scripts/sign.sh "$s" ed25519 "$k/a-public.pem" >/dev/null && [ -f "$s/a.txt.sig" ] && ok "ed25519 signs with a key path" || bad "ed25519 signing with a key path"
grep -q 'get("app_name")' templates/app.spec && ok "spec reads app_name" || bad "templates/app.spec must read NAME from app_name"
grep -q '^APP=app$' scripts/install-linux.sh && ok "install helper has the APP=app line the build replaces" || bad "install-linux.sh needs an APP=app line"
p="$t/pkg"; mkdir -p "$p/src"; echo hi > "$p/src/demo"
bash scripts/make_sh.sh "$p/src" "$p/demo.sh" demo >/dev/null && grep -q '.local/share/demo' "$p/demo.sh" \
  && ok "make_sh installs to ~/.local/share/<app_name>" || bad "make_sh must default to ~/.local/share/<app_name>"
if command -v dpkg-deb >/dev/null 2>&1; then
  bash scripts/make_deb.sh "$p/src" My_Demo 1.2 "$p" >/dev/null 2>&1 && [ "$(dpkg-deb -f "$p/My_Demo-1.2-linux-amd64.deb" Package)" = "my-demo" ] \
    && ok "make_deb names the file from app_name and lowercases the package" || bad "make_deb name handling"
else echo "skip: dpkg-deb not installed"; fi
for f in templates/release.yml scripts/release_local.sh; do
  grep -q -- '--distpath build/dist' "$f" && ok "pyinstaller distpath in $f" || bad "pyinstaller must write to build/dist in $f"
done

# 7. The Dockerfile templates build on the samples (CI sets DOCKER_BUILD=1; needs a running Docker)
if [ "${DOCKER_BUILD:-0}" = 1 ]; then
  for s in flask fastapi python-uv; do
    docker build -q -t "skilltest-$s" "$t/docker-$s" >/dev/null && ok "docker build $s" || bad "docker build $s"
  done
  for target in spa server; do
    docker build -q --target "$target" -t "skilltest-node-$target" "$t/docker-node" >/dev/null && ok "docker build node --target $target" || bad "docker build node --target $target"
  done
else
  echo "skip: docker builds (set DOCKER_BUILD=1)"
fi

[ "$fail" = 0 ] && echo "all checks passed" || { echo "checks failed" >&2; exit 1; }
