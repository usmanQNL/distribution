#!/usr/bin/env bash
# Usage: sign.sh <dir> <cosign|ed25519|check-key> [public-key.pem]
#   cosign:    keyless Sigstore bundle per file (.bundle holds signature and certificate). Needs id-token: write.
#   ed25519:   signature per file (.sig) using RELEASE_SIGNING_KEY: the PEM private key itself (the GitHub secret),
#              or, for local runs, the path to the key file (for example root-private.pem).
#              If a public key path is given, each signature is verified after signing.
#   check-key: only checks RELEASE_SIGNING_KEY (set, an Ed25519 private key, and matching the public key if given),
#              so a release can stop before the build instead of at the signing step. <dir> is not used.
set -euo pipefail
dir="${1:?usage: sign.sh <dir> <cosign|ed25519> [public-key.pem]}"
mode="${2:?usage: sign.sh <dir> <cosign|ed25519> [public-key.pem]}"
pub="${3:-}"

signable() { # skip signatures and certificates, sign everything else
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    case "$f" in *.sig|*.pem|*.bundle) continue ;; esac
    printf '%s\n' "$f"
  done
}

# RELEASE_SIGNING_KEY holds the PEM text, or the path to a PEM file. Sets keyfile, after checking the key.
keyfile=""
key_file() {
  if [ -z "${RELEASE_SIGNING_KEY:-}" ]; then
    echo "RELEASE_SIGNING_KEY is not set. In GitHub: add the repo secret RELEASE_SIGNING_KEY with the whole private key file (for example root-private.pem) pasted in. Locally: export RELEASE_SIGNING_KEY=/path/to/root-private.pem" >&2
    exit 1
  fi
  if [ -f "$RELEASE_SIGNING_KEY" ]; then
    keyfile="$RELEASE_SIGNING_KEY"
  else
    keyfile="$(mktemp)"; trap 'rm -f "$keyfile"' EXIT
    printf '%s\n' "$RELEASE_SIGNING_KEY" > "$keyfile"
  fi
  if ! openssl pkey -in "$keyfile" -noout -text 2>/dev/null | grep -qi 'ED25519 Private-Key'; then
    echo "RELEASE_SIGNING_KEY is set but is not an Ed25519 private key in PEM form. Use the whole file, from -----BEGIN PRIVATE KEY----- to -----END PRIVATE KEY-----." >&2
    exit 1
  fi
  if [ -n "$pub" ] && ! cmp -s <(openssl pkey -in "$keyfile" -pubout 2>/dev/null) <(openssl pkey -pubin -in "$pub" -pubout 2>/dev/null); then
    echo "RELEASE_SIGNING_KEY does not match the public key $pub: signatures would not verify. Use the private key that $pub was made from." >&2
    exit 1
  fi
}

case "$mode" in
  cosign)
    while IFS= read -r f; do
      cosign sign-blob --yes --bundle "$f.bundle" "$f"
    done < <(signable)
    ;;
  cosign-sums)  # one signature for SHA256SUMS only; it covers every artifact by checksum
    cosign sign-blob --yes --bundle "$dir/SHA256SUMS.bundle" "$dir/SHA256SUMS"
    ;;
  check-key)
    key_file
    echo "RELEASE_SIGNING_KEY is set and is an Ed25519 private key${pub:+ that matches $pub}"
    exit 0
    ;;
  ed25519)
    key_file
    while IFS= read -r f; do
      openssl pkeyutl -sign -inkey "$keyfile" -rawin -in "$f" -out "$f.sig"
      if [ -n "$pub" ]; then
        openssl pkeyutl -verify -pubin -inkey "$pub" -rawin -in "$f" -sigfile "$f.sig" >/dev/null
      fi
    done < <(signable)
    ;;
  *)
    echo "unknown signing mode: $mode (use cosign, cosign-sums, ed25519 or check-key)" >&2
    exit 1
    ;;
esac
echo "signed with $mode"
