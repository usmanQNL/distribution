#!/usr/bin/env bash
# Deploy without PyInstaller: install the project with uv and run it on the target machine.
# Ships inside the <app_name>-<version>-uv.tar.gz release. Extract it, then run: bash scripts/uv-deploy.sh
# The project needs a pyproject.toml. Set APP_CMD to change the command, e.g. APP_CMD="python app.py".
set -euo pipefail
cd "$(dirname "$0")"
[ -f pyproject.toml ] || cd ..
[ -f pyproject.toml ] || { echo "no pyproject.toml found next to this script or one folder up" >&2; exit 1; }
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
fi
uv sync --frozen 2>/dev/null || uv sync
read -r -a cmd <<< "${APP_CMD:-python main.py}"
exec uv run "${cmd[@]}"
