# Agent instructions

This repo is the distribution skill itself. `SKILL.md` holds the instructions an agent follows to set up releases in a project, and `README.md` gives the overview. `distribution.md` is the agent-neutral guide that `generate.sh` copies into each project: here it stays a blank template (it must match `templates/distribution.md`), so this repo's own release answers live in `distribution.json`.

## This repo's own release

- It releases the Flask sample (`test/samples/flask`) with every target except the Node SPA zip, named `distribution-<version>-<platform>` (`app_name` is `distribution`).
- Pull requests build only. Merges to main publish to `usmanQNL/distribution-test`, signed with cosign. The Docker image goes to `ghcr.io/usmanqnl/distribution`.

## Standing rules

- **Remote-first.** Work in a cloud checkout of the GitHub repo and keep its default branch up to date. Do not depend on the user's PC; the user runs `git pull` when they want to test locally.
- **Sign off every commit** with `git commit -s`. The skill is licensed MIT OR Apache-2.0, and CI's `dco` job fails a pull request with an unsigned commit (see `CONTRIBUTING.md`).
- **Run `bash scripts/test_skill.sh` before you push.** It checks the copies that must stay identical: `distribution.md` and `templates/distribution.md`, `.github/workflows/release.yml` and `templates/release.yml`, and the other pairs it lists.
- **Document only what is built.** Unbuilt setup choices (frontend beside the exe, manual tag, Actions-only artifacts, `repository_dispatch`) stay under "Not done yet" in `distribution.md`.
- **Clean up after every merge.** Delete the PR's branch (local and remote) and any worktree it used. If GitHub refuses the delete, tell the user the exact command to run.
