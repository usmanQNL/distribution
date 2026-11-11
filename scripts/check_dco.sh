#!/usr/bin/env bash
# Fails when a commit in BASE..HEAD lacks a DCO sign-off by its author.
# Usage: scripts/check_dco.sh <base-ref> [head-ref]
set -euo pipefail
base="${1:?usage: check_dco.sh <base-ref> [head-ref]}"
head="${2:-HEAD}"
fail=0
for c in $(git rev-list --no-merges "$base..$head"); do
  author="$(git log -1 --format='%an <%ae>' "$c")"
  if git log -1 --format='%B' "$c" | grep -qiF "Signed-off-by: $author"; then
    echo "ok: $(git log -1 --format='%h %s' "$c")"
  else
    echo "FAIL: $(git log -1 --format='%h %s' "$c") has no 'Signed-off-by: $author'" >&2
    fail=1
  fi
done
if [ "$fail" -ne 0 ]; then
  echo "Sign off each commit with 'git commit -s'. To fix existing commits: git rebase --signoff $base, then force-push. See CONTRIBUTING.md." >&2
fi
exit "$fail"
