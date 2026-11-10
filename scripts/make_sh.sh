#!/usr/bin/env bash
# Usage: make_sh.sh <src-dir> <out-file.sh>  -> self-extracting shell installer for a folder
set -euo pipefail
src="${1:?usage: make_sh.sh <src-dir> <out.sh>}"; out="${2:?usage: make_sh.sh <src-dir> <out.sh>}"
payload="$(mktemp)"
tar -C "$src" -czf "$payload" .
{
  echo '#!/usr/bin/env bash'
  echo 'set -euo pipefail'
  echo 'dest="${1:-$HOME/.local/share/app}"; mkdir -p "$dest"'
  echo 'n=$(awk "/^__PAYLOAD__$/{print NR+1; exit 0}" "$0")'
  echo 'tail -n +"$n" "$0" | tar -xz -C "$dest"'
  echo 'echo "installed to $dest"; exit 0'
  echo '__PAYLOAD__'
  cat "$payload"
} > "$out"
chmod +x "$out"; rm -f "$payload"; echo "wrote $out"
