# distribution skill

A shareable Claude skill that sets up release builds for a Python, Node or mixed codebase. Every merge to main builds artifacts, writes SHA256 checksums, signs them with cosign (Sigstore), and publishes a GitHub release to a separate public releases repository.

## What it produces

- Windows `.exe` (PyInstaller)
- Linux `.sh` self-extracting installer and `.deb` package (built on Ubuntu runners)
- A zipped SPA (`frontend-<os>.zip`) when the Node project has a `build` script
- `SHA256SUMS` plus a cosign signature and certificate for each file

Python projects can also deploy with uv instead of PyInstaller (`templates/uv-deploy.sh`).

## How to use

1. Add the skill to Claude.
2. Ask Claude to set up distribution for your repo.
3. Answer the questions. Each one lists pros and cons with a recommendation.
4. Claude runs `scripts/detect.sh` and `scripts/generate.sh`, then guides you through the GitHub setup.
5. Commit the generated files and push. The release workflow runs on the next merge to main.

## Layout

- `SKILL.md`: the instructions Claude follows
- `templates/release.yml`: the GitHub Actions workflow
- `templates/app.spec`: PyInstaller spec, with placeholders for entry point and frontend
- `templates/uv-deploy.sh`: uv-based run script for targets without PyInstaller
- `scripts/detect.sh`, `scripts/generate.sh`: detect the project and copy the templates
- `scripts/checksums.sh`, `scripts/sign.sh`: SHA256SUMS and cosign signing
- `scripts/make_sh.sh`, `scripts/make_deb.sh`: Linux installer and package
- `test/samples/`: HelloWorld apps for node, python-uv, flask, streamlit and fastapi

## Status

Scripts are tested locally where the host allows: detection on all samples, the Node build, checksums, the .sh installer and the spec syntax. The PyInstaller build, the .deb build, cosign signing and the release publish run only in GitHub Actions, so they still need a real CI run.
