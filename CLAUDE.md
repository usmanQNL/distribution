# Agent instructions

For releases, builds, signing or publishing, read `distribution.md` first. It is the agent-neutral guide: setup answers, repos, secrets, folders and steps.

## Standing rules

- **Remote-first.** Work in a cloud checkout of the GitHub repo and keep its default branch up to date. Do not depend on the user's PC; the user runs `git pull` when they want to test locally.
- **Clean up after every merge.** Delete the PR's branch (local and remote) and any worktree it used. If GitHub refuses the delete, tell the user the exact command to run.
