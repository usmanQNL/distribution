#!/usr/bin/env bash
# Deploy without PyInstaller: install the project with uv and run it. Copy to the target machine.
set -euo pipefail
cd "$(dirname "$0")"
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
uv sync --frozen 2>/dev/null || uv sync
exec uv run "${APP_CMD:-python main.py}"
