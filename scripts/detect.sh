#!/usr/bin/env bash
# Usage: detect.sh <project-dir>  -> prints language and shape as key=value
#   uses_env=yes when the app reads a .env file: a .env or .env.example (.sample, .template) is there,
#   python-dotenv or dotenv is a dependency, or the code loads one (load_dotenv, require('dotenv'), dotenv/config).
set -euo pipefail
dir="${1:?usage: detect.sh <project-dir>}"
py=0; node=0; framework=none
if [ -f "$dir/pyproject.toml" ] || [ -f "$dir/requirements.txt" ]; then py=1; fi
if [ -f "$dir/package.json" ]; then node=1; fi
if [ $py = 1 ]; then
  for f in flask fastapi streamlit; do
    if [ "$framework" = none ] && grep -qiw "$f" "$dir/requirements.txt" "$dir/pyproject.toml" 2>/dev/null; then framework=$f; fi
  done
fi
if [ $py = 1 ] && [ $node = 1 ]; then lang=mix
elif [ $py = 1 ]; then lang=python
elif [ $node = 1 ]; then lang=node
else lang=unknown; fi
echo "language=$lang"
echo "python_framework=$framework"
env=no
for f in .env .env.example .env.sample .env.template; do if [ -f "$dir/$f" ]; then env=yes; fi; done
if [ $env = no ] && grep -qiE '(^|[^a-z_-])(python-dotenv|dotenv)([^a-z_-]|$)' "$dir/requirements.txt" "$dir/pyproject.toml" "$dir/package.json" 2>/dev/null; then env=yes; fi
if [ $env = no ] && grep -rqE --include='*.py' --include='*.js' --include='*.mjs' --include='*.cjs' --include='*.ts' \
     --exclude-dir=node_modules --exclude-dir=.venv --exclude-dir=venv --exclude-dir=.git \
     'load_dotenv|dotenv_values|require\(.dotenv.\)|from .dotenv.|dotenv/config' "$dir" 2>/dev/null; then env=yes; fi
echo "uses_env=$env"
