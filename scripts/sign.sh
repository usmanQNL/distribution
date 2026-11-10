#!/usr/bin/env bash
# Usage: sign.sh <dir> <cosign|ed25519> [public-key.pem]
#   cosign:  keyless Sigstore signature per file (.sig + .pem certificate). Needs id-token: write.
#   ed25519: signature per file (.sig) using the RELEASE_SIGNING_KEY env var (PEM private key).
#            If a public key path is given, each signature is verified after signing.
set -euo pipefail
dir="${1:?usage: sign.sh <dir> <cosign|ed25519> [public-key.pem]}"
mode="${2:?usage: sign.sh <dir> <cosign|ed25519> [public-key.pem]}"
pub="${3:-}"

signable() { # skip signatures and certificates, sign everything else
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.sig|*.pem) continue ;; esac
    printf '%s\n' "$f"
  done
}

case "$mode" in
  cosign)
    while IFS= read -r f; do
      cosign sign-blob --yes "$f" --output-signature "$f.sig" --output-certificate "$f.pem"
    done < <(signable)
    ;;
  ed25519)
    : "${RELEASE_SIGNING_KEY:?set the RELEASE_SIGNING_KEY secret (PEM private key)}"
    keyfile="$(mktemp)"
    trap 'rm -f "$keyfile"' EXIT
    printf '%s\n' "$RELEASE_SIGNING_KEY" > "$keyfile"
    while IFS= read -r f; do
      openssl pkeyutl -sign -inkey "$keyfile" -rawin -in "$f" -out "$f.sig"
      if [ -n "$pub" ]; then
        openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$f" -sigfile "$f.sig" >/dev/null
      fi
    done < <(signable)
    ;;
  *)
    echo "unknown signing mode: $mode (use cosign or ed25519)" >&2
    exit 1
    ;;
esac
echo "signed with $mode"
