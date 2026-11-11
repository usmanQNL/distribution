# Distribution (agent-neutral guide)

Read this file first if you are asked to build, sign or publish release artifacts for this project. It is written so any agent (any model provider) can run the release cycle from scratch.

## What this does
On every push to `main` (and on manual run), GitHub Actions builds the selected artifacts, writes `SHA256SUMS`, signs them, and publishes a GitHub release to a separate public releases repository.

## Files in this project
- `distribution.json`: the answers. Language, entry point, selected artifacts, signing mode. Edit this to change what is built.
- `.github/workflows/release.yml`: the workflow. Do not edit unless changing the pipeline.
- `packaging/app.spec`: PyInstaller spec. `ENTRY` is relative to `packaging/`, so use `../` for paths from the repo root.
- `packaging/installer.iss`: Inno Setup script, used only when `windows_inno_installer` is true.
- `templates/install-linux.sh` (copied to the release as `install-linux.sh` when a Linux installer is selected): installs the app for the user, or system-wide with `--system`.
- `packaging/keys/release-signing-public.pem`: public key, only for `ed25519` signing. Never put the private key in the repo.
- `scripts/checksums.sh`, `scripts/sign.sh`, `scripts/make_sh.sh`, `scripts/make_deb.sh`: build and signing helpers.
- `VERSION`: the major version number. The release tag is `v<VERSION>.<yyyymmdd_hhmm>` in UTC.

## Answers recorded at setup (edit `distribution.json` to change)
| Question | Answer used | Options |
|---|---|---|
| Language | set per project | python, node, mix |
| Python framework | set per project | flask, fastapi, streamlit, none |
| Frontend bundling (Python + SPA) | bundle in the executable (recommended) | bundle, or ship beside |
| Windows .exe | on by default | on/off |
| Windows Inno Setup installer | off by default | on/off |
| Linux .sh | off by default | on/off |
| Linux .deb | off by default | on/off |
| Node SPA zip | off by default | on/off |
| uv deploy | off by default (no build) | on/off |
| Build location | `github` (default) | `github` (Actions builds, signs, publishes) or `local` (run `scripts/release_local.bat` on Windows, or `scripts/release_local.sh` elsewhere) |
| Signing | `cosign` (default) | `cosign` or `ed25519`. CI signs each file with cosign. Local `cosign` mode signs only `SHA256SUMS` (one sign-in per run), so verify local releases with `SHA256SUMS.bundle`. Use `cosign-all` in the script for per-file bundles. |
| Trigger | every merge to main, plus manual run | |
| Publish | separate public releases repo | |
| Artifact retention | 7 days (recorded as `artifact_retention_days` in `distribution.json`; pruning not implemented yet) | |

## Repos, secrets, folders (as used in this project)
- Skill source: `usmanQNL/distribution` (local: `C:\development\claudeCode\skills\distribution`).
- Releases repo for tests: `usmanQNL/distribution-test` (must not be empty: it needs at least one commit before a release can be created).
- `distribution.json` field `releases_repo` (used by local runs): `usmanQNL/distribution-test` in the test project.
- Repo variable (optional, GitHub runs): `RELEASES_REPO` = `<owner>/<releases-repo>`. If unset, the workflow uses `<repo>-releases`.
- Repo secret: `RELEASES_REPO_TOKEN`. A fine-grained token: resource owner `usmanQNL`, repository access selected to the releases repo only, Contents read and write. Created on GitHub under Settings, Developer settings, Personal access tokens, Fine-grained tokens. Never commit it or paste it in chat.
- Repo secret (ed25519 only): `RELEASE_SIGNING_KEY`, the whole PEM private key.
- Local QuellDAP working folder (the source project for the first real use): `C:\development\claudeCode\quelldap`.

## Build location
- `github` (default): GitHub Actions builds, checksums, signs and publishes on every push to main. Artifacts pass between jobs and are kept by GitHub for the retention period.
- `local`: nothing runs in Actions. On Windows the user runs `scripts\release_local.bat` (it calls the .sh through Git Bash). On Linux or macOS they run `scripts/release_local.sh`. Either one builds the selected artifacts, checksums and signs them (with cosign locally, only `SHA256SUMS` is signed, so one browser sign-in per run covers every artifact by checksum; `cosign-all` in the script signs each file instead), and publishes with `gh release create` to `releases_repo` in `distribution.json`. Needs: PyInstaller, `zip` (Node), `dpkg-deb` (.deb, Linux), Inno Setup 6 (installer, Windows), cosign or openssl, and `gh` logged in (or `GH_TOKEN` set). Build only on the matching OS: `.exe` and Inno on Windows, `.sh` and `.deb` on Linux.
- The releases repo fields: `releases_repo` in `distribution.json`, or the `RELEASES_REPO` env var for local runs.

## Git on the local machine
Local runs refuse to start unless git is installed and `gh` is logged in. If git is missing, the agent should offer to install it, and must not run the local release until it is installed.

Install: Windows: `winget install --id Git.Git -e`, or the installer from https://git-scm.com. macOS: `xcode-select --install` or `brew install git`. Debian or Ubuntu: `sudo apt install git`.

Log in (one time per machine):
1. Install the GitHub CLI: `winget install --id GitHub.cli` (Windows), `brew install gh` (macOS), or `sudo apt install gh` (Debian or Ubuntu).
2. Log in: `gh auth login`. Choose GitHub.com, HTTPS, and "Login with a web browser". Copy the one-time code it shows, then press Enter to open the browser and paste it.
3. Let git use the same login: `gh auth setup-git`.
4. Set your identity for commits, if not set yet: `git config --global user.name "Your Name"` and `git config --global user.email "you@example.com"`.
5. Check: `gh auth status` should show you logged in to github.com, and `git --version` should print a version.

Use a token instead of the browser (for scripts): `gh auth login --with-token` reads a fine-grained token from stdin. Never paste a token into chat or commit it.

## Setup steps (do these in order)
1. Run `scripts/detect.sh <project-dir>` to get the language and framework.
2. Ask the user each question in the table above. Ask about each artifact separately. Record every answer in `distribution.json`.
3. Run `scripts/generate.sh <project-dir>` to copy the workflow, config and this guide into the project.
4. Commit and push the generated files. The user commits and pushes from their PC unless they ask otherwise.
5. Create the releases repo (public). Add at least one commit to it.
6. Create `RELEASES_REPO_TOKEN` as above and add it as a repo secret in the project repo.
7. If `ed25519`: generate the key pair (below), commit the public key, add the private key as `RELEASE_SIGNING_KEY`.
8. Run the workflow from the Actions tab (Run workflow) and check the run.
9. Verify the release (below).

### Ed25519 key pair
```
openssl genpkey -algorithm ed25519 -out release-signing-private.pem
mkdir -p packaging/keys
openssl pkey -in release-signing-private.pem -pubout -out packaging/keys/release-signing-public.pem
```
Commit only the public key. Put the private file into the `RELEASE_SIGNING_KEY` secret, then keep or delete the local copy. Never commit it.

## Verify a release
- Checksums: `sha256sum -c SHA256SUMS`
- cosign: `cosign verify-blob --bundle <file>.bundle --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com <file>`
- ed25519: `openssl pkeyutl -verify -pubin -inkey packaging/keys/release-signing-public.pem -rawin -in <file> -sigfile <file>.sig`

## Known gotchas (learned the hard way)
- PyInstaller resolves `ENTRY` relative to the spec's folder (`packaging/`).
- The publish job must check out the repo, or `scripts/` is missing.
- An empty releases repo fails with HTTP 422 "Repository is empty".
- A 403 from `gh release create` means the token is missing repo access or Contents write.
- The workflow runs use one concurrency group, so runs go one after another.
- Packaging order: Linux `.sh` and `.deb` must be built after PyInstaller. The raw Linux binary is removed from the release once `.sh` or `.deb` contains it.
- Node 24 is the target. Actions are pinned to Node 24 runtimes (checkout v5, setup-node v5, setup-python v6, upload and download artifact v5). `cosign-installer` is still v3 and not yet checked against Node 24.

## Not done yet (do not assume these work)
- cosign signing, the publish step and the PyInstaller build were verified only in CI, and only partly.
- uv deploy and Docker are not tested. Docker is not generated.
- The 7-day artifact retention and pruning are not in the template yet.
- The .deb build has not been checked on a real Ubuntu runner end to end.
