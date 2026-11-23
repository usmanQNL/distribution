# Agent instructions

For releases, builds, signing or publishing, read `distribution.md` first. It is the agent-neutral guide: setup answers, repos, secrets, folders and steps.

- Release files are named `<app_name>-<version>-<platform>`, with `app_name` from `distribution.json`.
- Never commit or paste a secret: not `RELEASES_REPO_TOKEN`, not `RELEASE_SIGNING_KEY`, not a real `.env`. Releases ship only `.env.example`, with no values.
