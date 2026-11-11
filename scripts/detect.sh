#!/usr/bin/env bash
# Usage: detect.sh <project-dir>  -> prints language and shape as key=value
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
