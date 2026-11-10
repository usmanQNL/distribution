#!/usr/bin/env bash
# Usage: sign.sh <dir>  -> keyless cosign signature per file (needs id-token: write)
set -euo pipefail
dir="${1:?usage: sign.sh <dir>}"
for f in "$dir"/*; do
  [ -f "$f" ] || continue
  cosign sign-blob --yes "$f" --output-signature "$f.sig" --output-certificate "$f.pem"
done
