#!/usr/bin/env bash
# Usage: env_example.sh <project-dir> <out-file>  -> writes the project's settings template to <out-file>.
# Uses the project's own .env.example (or .env.sample, .env.template). If only .env exists, writes a copy
# with every value removed: only variable names are kept, so no secret can leak. The real .env is never copied.
# Writes nothing, and still exits 0, when the project has none of these files.
# Usage: env_example.sh --notes <release-dir>  -> prints release notes saying where .env goes for each file in the
#   release, when it holds <app_name>-<version>-env.example. Prints nothing otherwise.
set -euo pipefail
if [ "${1:-}" = --notes ]; then
  rel="${2:?usage: env_example.sh --notes <release-dir>}"
  ex="$(cd "$rel" && ls -- *-env.example 2>/dev/null | head -n1 || true)"
  [ -n "$ex" ] || exit 0
  name="$(printf '%s' "${ex%-env.example}" | sed -E 's/-[0-9][0-9.]*$//')"
  has() { compgen -G "$rel/$1" >/dev/null; }
  echo
  echo "### Settings (.env)"
  echo "This app reads its settings from a \`.env\` file. Download \`$ex\`, rename it to \`.env\`, fill in the values, and put it here:"
  has "*-windows.exe" && echo "- Windows .exe: the same folder as the .exe."
  has "*-windows-setup.exe" && echo "- Windows installer: the install folder, by default \`C:\\Program Files\\$name\` (editing files there needs administrator rights). The installer puts \`.env.example\` there too."
  has "*-linux.sh" && echo "- Linux .sh: \`~/.local/share/$name/.env\`, or \`/opt/$name/.env\` after an install with \`--system\`."
  has "*-linux-amd64.deb" && echo "- Linux .deb: \`/opt/$name/.env\` (needs sudo)."
  has "*-uv.tar.gz" && echo "- uv bundle: the extracted folder, next to \`pyproject.toml\`."
  has "*-docker.txt" && echo "- Docker: pass it with \`docker run --env-file .env ...\`, or mount it with \`-v \"\$PWD/.env:/app/.env:ro\"\`."
  echo
  echo "Variables already set in the environment win over the file."
  exit 0
fi
dir="${1:?usage: env_example.sh <project-dir> <out-file>}"; out="${2:?usage: env_example.sh <project-dir> <out-file>}"
mkdir -p "$(dirname "$out")"
for f in .env.example .env.sample .env.template; do
  if [ -f "$dir/$f" ]; then cp "$dir/$f" "$out"; echo "wrote $out from $f"; exit 0; fi
done
if [ -f "$dir/.env" ]; then
  # Keep blank lines and the names of set (NAME=) and commented-out (# NAME=) variables. Drop everything else:
  # values, free comments and the lines of multi-line values.
  {
    echo "# Copy this file to .env and fill in the values."
    awk '
      /^[[:space:]]*$/ { print ""; next }
      match($0, /^[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) {
        s = substr($0, 1, RLENGTH - 1); sub(/^[[:space:]]*(export[[:space:]]+)?/, "", s); sub(/[[:space:]]+$/, "", s); print s "="; next
      }
      match($0, /^[[:space:]]*#[[:space:]]*(export[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=/) {
        s = substr($0, 1, RLENGTH - 1); sub(/^[[:space:]]*#[[:space:]]*(export[[:space:]]+)?/, "", s); sub(/[[:space:]]+$/, "", s); print "# " s "="; next
      }
    ' "$dir/.env" | cat -s
  } > "$out"
  echo "wrote $out from .env, with every value removed"
  exit 0
fi
echo "no .env.example or .env in $dir: no settings template to ship" >&2
