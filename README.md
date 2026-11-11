# distribution skill

A shareable Claude skill that sets up release builds for a Python, Node or mixed codebase. Every merge to main builds artifacts (and, if chosen, a Docker image) (on GitHub, or locally with `scripts/release_local.sh`), writes SHA256 checksums, signs them with cosign (Sigstore) or Ed25519, chosen in setup, and publishes a GitHub release to a separate public releases repository.

## What it produces

- Windows `.exe` (PyInstaller)
- Linux `.sh` self-extracting installer and `.deb` package (built on Ubuntu runners)
- A zipped SPA (`<name>-<version>-frontend.zip`) when the Node project has a `build` script
- A Windows installer (Inno Setup). The build needs ISCC, the Inno Setup 6 compiler: the skill checks for it during setup, and `scripts/ensure_iscc.sh` installs it when it is missing (choco on the GitHub Windows runner, winget or choco on a local Windows machine). Inno Setup runs only on Windows, so on Linux or macOS the local run skips the installer and says why.
- A Docker image, if the user asks for one: the skill writes a `Dockerfile` and `.dockerignore`, every pull request builds the image, and every merge pushes it to GitHub Container Registry (`ghcr.io/<owner>/<repo>:<version>` and `:latest`), signed with cosign, with its digest in the release as `<name>-<version>-docker.txt`
- Every file named `<name>-<version>-<platform>`, where `<name>` is the release name the user picks at setup (the project name by default), for example `acme-notes-1.202611110638-windows.exe`
- `SHA256SUMS` plus a signature for each file (cosign with certificate, or Ed25519)
- A settings template, `<name>-<version>-env.example`, when the app reads a `.env` file (see below)

Python projects can also deploy with uv instead of PyInstaller (`scripts/uv-deploy.sh`, shipped in a source bundle).

## How to use

1. Add the skill to Claude.
2. Ask Claude to set up distribution for your repo.
3. Answer the questions. Each one lists pros and cons with a recommendation.
4. Claude runs `scripts/detect.sh` and `scripts/generate.sh`, then guides you through the GitHub setup.
5. Commit the generated files and push. The release workflow runs on the next merge to main.

**Full Linux + Windows + Docker release: choose GitHub (Actions) as the build location.** Only GitHub Actions builds every target, on its Windows and Linux runners, and pushes the Docker image, all into one release. A local build makes only the packages for the machine it runs on (the .exe and installer on Windows, the .sh and .deb on Linux), never builds the Docker image, and publishes a separate release each time it runs. Local is useful for a quick single-platform release or for testing a build.

**Where each file goes.** Only the Docker image goes to GitHub Container Registry (GHCR), and only with GitHub (Actions) builds. On every merge to main the workflow pushes it to `ghcr.io/<owner>/<repo>` (`:<version>` and `:latest`), signs it with cosign (with Ed25519 signing, the signed digest file below vouches for it instead), and adds `<name>-<version>-docker.txt` with the image digest to the release. Pull requests only build the image. A new GHCR package starts out private: to let anyone pull it, open the package, Package settings, Change visibility, Public. The Windows and Linux files (.exe, installer, .sh, .deb) are not container images, so they go to the releases repo as a GitHub Release, with `SHA256SUMS` and signatures. A local run never builds Docker, so nothing from it reaches GHCR.

For local releases (`scripts/release_local.sh`, or `scripts\release_local.bat` on Windows), the script first checks for the GitHub CLI (`gh`) and installs it if it is missing (winget or choco on Windows, brew on macOS, the official apt repo or dnf, pacman or zypper on Linux). It then checks that `gh` is logged in and starts `gh auth login` if it is not (or set `GH_TOKEN`). When the Windows installer is chosen it does the same for Inno Setup.

### Apps that read a .env file

`scripts/detect.sh` reports `uses_env=yes` when the app has a `.env` or `.env.example`, depends on `python-dotenv` or `dotenv`, or calls `load_dotenv`. Every release then ships a settings template, `<name>-<version>-env.example`, checksummed and signed like the other files, and puts `.env.example` next to the program inside the Windows installer, the Linux `.sh` and the `.deb`. The template is the project's own `.env.example`. If the project has only a `.env`, `generate.sh` writes `.env.example` from it with every value removed (names only) for you to check and commit, and adds `.env` to `.gitignore`. The real `.env` is never shipped.

Where users put `.env` (copy the template, rename it to `.env`, fill it in):

| Release file | Where `.env` goes |
|---|---|
| Windows `.exe` | The same folder as the `.exe` |
| Windows installer | The install folder, by default `C:\Program Files\<name>` (editing it there needs administrator rights) |
| Linux `.sh` | `~/.local/share/<name>/.env`, or `/opt/<name>/.env` after a `--system` install |
| Linux `.deb` | `/opt/<name>/.env` (needs sudo) |
| uv bundle | The extracted folder, next to `pyproject.toml` |
| Docker | Not in the image: `docker run --env-file .env ...`, or mount it at `/app/.env` |

These locations work wherever the program is started from (a shortcut, the Start menu, a command on `PATH`): the PyInstaller build includes a small runtime hook, `packaging/env_hook.py`, that loads the `.env` next to the executable. Without it, a built app's `load_dotenv()` looks only in the current folder. Variables already set in the environment win over the file. Each release's notes list the locations for the files in that release.

### Ed25519 signing: set RELEASE_SIGNING_KEY

If you chose Ed25519 signing, set `RELEASE_SIGNING_KEY` to your private key, `root-private.pem` (the key whose public half is `packaging/keys/release-signing-public.pem`):

- **GitHub builds:** add a repo secret named `RELEASE_SIGNING_KEY` (Settings, Secrets and variables, Actions) and paste in the whole contents of `root-private.pem`, from `-----BEGIN PRIVATE KEY-----` to `-----END PRIVATE KEY-----`. A secret holds text, not a file path.
- **Local builds:** `export RELEASE_SIGNING_KEY="$HOME/keys/root-private.pem"` (a path to the file, or its contents).

The release checks the key before it builds anything: it must be set, be an Ed25519 private key, and match the committed public key. On `main` a missing or wrong key stops the run straight away; on pull requests a missing key is only a warning, because pull requests from forks get no secrets. You can run the same check yourself with `bash scripts/sign.sh - check-key packaging/keys/release-signing-public.pem`.

Keep `root-private.pem` outside the repo. `.gitignore` already ignores `*-private.pem`, but a key that never sits in the working tree cannot be committed by mistake.

## Layout

- `SKILL.md`: the instructions Claude follows
- `distribution.md`: the agent-neutral guide (copied into each project)
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`: pointers to the guide
- `templates/release.yml`: the GitHub Actions workflow
- `templates/Dockerfile.python`, `templates/Dockerfile.node`, `templates/dockerignore`: Docker files, copied only when the user picks Docker
- `templates/app.spec`, `templates/installer.iss`: PyInstaller spec (with placeholders for entry point and frontend) and Inno Setup script, both named from `app_name`
- `scripts/detect.sh`, `scripts/generate.sh`: detect the project and copy the templates
- `scripts/checksums.sh`, `scripts/sign.sh`: SHA256SUMS and cosign signing
- `scripts/env_example.sh`, `templates/env_hook.py`: the `.env.example` that releases ship, and the PyInstaller hook that loads `.env` from next to the program
- `scripts/make_sh.sh`, `scripts/make_deb.sh`, `scripts/install-linux.sh`: Linux installer, package and install helper
- `scripts/uv-deploy.sh`: uv-based run script for targets without PyInstaller
- `scripts/prune_releases.sh`: opt-in deletion of old releases
- `scripts/ensure_gh.sh`: finds the GitHub CLI or installs it (winget or choco on Windows, brew on macOS, apt, dnf, pacman or zypper on Linux), used by local releases, which publish with `gh` (`--check` only looks)
- `scripts/ensure_iscc.sh`: finds ISCC or installs Inno Setup 6, used only when the Windows installer is chosen (`--check` only looks)
- `scripts/release_local.sh`, `scripts/release_local.bat`: local builds. On Windows the .bat runs the .sh with Git's own `bash.exe`, found from `git.exe` (per-user installs too), never a bare `bash`, which may be WSL's
- `scripts/test_skill.sh`: the skill's own checks, run in CI
- `scripts/check_dco.sh`: the DCO sign-off check, run in CI on every pull request, repo-only (not copied into projects)
- `test/samples/`: HelloWorld apps for node, python-uv, flask, streamlit and fastapi
- `LICENSE`, `LICENSE-MIT`, `LICENSE-APACHE`: the skill's dual license
- `CONTRIBUTING.md`: how to contribute, including the DCO sign-off

## Status

`scripts/test_skill.sh` runs in CI on every pull request, with shellcheck and actionlint. This repo also runs its own release workflow on the Flask sample: every pull request builds the Windows exe and installer, the Linux .sh and .deb, the uv bundle, the Docker image and the settings template (the sample reads `GREETING` from `.env`), and every merge to main publishes them, signed with cosign, to `usmanQNL/distribution-test` (the image goes to `ghcr.io/usmanqnl/distribution`). CI also builds the Dockerfile templates against the sample apps.

## License

Licensed under either of the [MIT License](LICENSE-MIT) or the [Apache License, Version 2.0](LICENSE-APACHE), at your option (`SPDX-License-Identifier: MIT OR Apache-2.0`). Contributions are accepted under the same terms and must be signed off under the Developer Certificate of Origin (`git commit -s`). See [CONTRIBUTING.md](CONTRIBUTING.md).

This license covers the skill itself. It does not apply to the projects the skill sets up: those keep their own license.
