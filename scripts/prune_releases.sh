#!/usr/bin/env bash
# Usage: prune_releases.sh <releases-repo> <keep-days> [--dry-run]
#   Deletes GitHub releases (and their tags) in the releases repo that are older than keep-days.
#   Opt-in only: the release workflow runs it when workflow_dispatch input prune_releases is true.
set -euo pipefail
repo="${1:?usage: prune_releases.sh <releases-repo> <keep-days> [--dry-run]}"
days="${2:?usage: prune_releases.sh <releases-repo> <keep-days> [--dry-run]}"
dry="${3:-}"
[[ "$days" =~ ^[0-9]+$ ]] || { echo "keep-days must be a whole number" >&2; exit 1; }
cutoff="$(date -u -d "-${days} days" +%Y-%m-%dT%H:%M:%SZ)"
echo "pruning releases in $repo published before $cutoff"
gh api --paginate "repos/$repo/releases?per_page=100" \
  --jq ".[] | select(.published_at < \"$cutoff\") | .tag_name" | while IFS= read -r tag; do
  if [ "$dry" = "--dry-run" ]; then
    echo "would delete $tag"
  else
    gh release delete "$tag" --repo "$repo" --cleanup-tag --yes
    echo "deleted $tag"
  fi
done
