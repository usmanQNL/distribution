# distribution skill

A shareable Claude skill that sets up release builds for a Python, Node or mixed codebase. Every merge to main builds artifacts (on GitHub, or locally with `scripts/release_local.sh`), writes SHA256 checksums, signs them with cosign (Sigstore) or Ed25519, chosen in setup, and publishes a GitHub release to a separate public releases repository.

## What it produces

- Windows `.exe` (PyInstaller)
- Linux `.sh` self-extracting installer and `.deb` package (built on Ubuntu runners)
- A zipped SPA (`app-<version>-frontend.zip`) when the Node project has a `build` script
- A Windows installer (Inno Setup)
- Every file named `app-<version>-<platform>`, for example `app-0.1.202611110638-windows.exe`
- `SHA256SUMS` plus a signature for each file (cosign with certificate, or Ed25519)

Python projects can also deploy with uv instead of PyInstaller (`scripts/uv-deploy.sh`, shipped in a source bundle).

## How to use

1. Add the skill to Claude.
2. Ask Claude to set up distribution for your repo.
3. Answer the questions. Each one lists pros and cons with a recommendation.
4. Claude runs `scripts/detect.sh` and `scripts/generate.sh`, then guides you through the GitHub setup.
5. Commit the generated files and push. The release workflow runs on the next merge to main.

## Layout

- `SKILL.md`: the instructions Claude follows
- `distribution.md`: the agent-neutral guide (copied into each project)
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`: pointers to the guide
- `templates/release.yml`: the GitHub Actions workflow
- `templates/app.spec`: PyInstaller spec, with placeholders for entry point and frontend
- `templates/app.spec`, `templates/installer.iss`: PyInstaller spec and Inno Setup script
- `scripts/detect.sh`, `scripts/generate.sh`: detect the project and copy the templates
- `scripts/checksums.sh`, `scripts/sign.sh`: SHA256SUMS and cosign signing
- `scripts/make_sh.sh`, `scripts/make_deb.sh`, `scripts/install-linux.sh`: Linux installer, package and install helper
- `scripts/uv-deploy.sh`: uv-based run script for targets without PyInstaller
- `scripts/prune_releases.sh`: opt-in deletion of old releases
- `scripts/release_local.sh`, `scripts/release_local.bat`: local builds
- `scripts/test_skill.sh`: the skill's own checks, run in CI
- `test/samples/`: HelloWorld apps for node, python-uv, flask, streamlit and fastapi

## Status

`scripts/test_skill.sh` runs in CI on every pull request, with shellcheck and actionlint. This repo also runs its own release workflow on the Flask sample: every pull request builds the Windows exe and installer, the Linux .sh and .deb and the uv bundle, and every merge to main publishes them, signed with cosign, to `usmanQNL/distribution-test`.
