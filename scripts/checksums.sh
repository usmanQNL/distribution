#!/usr/bin/env bash
# Usage: checksums.sh <dir>  -> writes <dir>/SHA256SUMS
set -euo pipefail
dir="${1:?usage: checksums.sh <dir>}"
cd "$dir"
find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\n' | sort | xargs sha256sum > SHA256SUMS
cat SHA256SUMS
