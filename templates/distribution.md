# Distribution (agent-neutral guide)

Read this file first if you are asked to build, sign or publish release artifacts for this project. It is written so any agent (any model provider) can run the release cycle from scratch.

## What this does
On every pull request, GitHub Actions builds the selected artifacts as a check. On every push to `main` (and on manual run), it also writes `SHA256SUMS`, signs the files, publishes a GitHub release to a separate public releases repository, and then deletes the build artifacts from Actions storage.

## Files in this project
Written by `scripts/generate.sh`. Every file is listed so an agent can find it without reading the scripts.
- `distribution.json`: the answers in machine form. The scripts read it. Edit it to change what is built. Besides `targets`, it holds `bundle_frontend`, `frontend_dir` (folder with `package.json`) and `frontend_dist` (its build output) for apps with a frontend.
- `distribution.md`: this file. It holds the human-readable record of the same answers.
- `.github/workflows/release.yml`: the GitHub Actions workflow. Do not edit unless changing the pipeline.
- `packaging/app.spec`: PyInstaller spec. `ENTRY` is relative to `packaging/`, so use `../` for paths from the repo root. PyInstaller writes to `build/dist/`, apart from a frontend's `dist/`.
- `packaging/installer.iss`: Inno Setup script. Used only when `windows_inno_installer` is true. Its paths are relative to `packaging/`, so the exe is `..\build\dist\app.exe`.
- `scripts/checksums.sh`: writes `SHA256SUMS`.
- `scripts/sign.sh`: signs with cosign or ed25519.
- `scripts/make_sh.sh`, `scripts/make_deb.sh`: Linux `.sh` installer and `.deb` package.
- `scripts/install-linux.sh`: installs the Linux release for a user, or system-wide with `--system`. Copied into each Linux release.
- `scripts/uv-deploy.sh`: runs the app with uv on the target. Used only when `uv_deploy` is true: the release gets `app-<version>-uv.tar.gz` (the source at that commit), and the target extracts it and runs `bash scripts/uv-deploy.sh`. Needs a `pyproject.toml`. `APP_CMD` sets the command (default `python main.py`).
- `Dockerfile`, `.dockerignore`: only when `targets.docker` is true. From `templates/Dockerfile.python` (Python or Mix) or `templates/Dockerfile.node` (Node, with a `spa` and a `server` stage; keep one). Fill in `CMD` and `EXPOSE`. The workflow's `docker` job builds it on every pull request and, on main, pushes `ghcr.io/<owner>/<repo>:<version>` and `:latest`, signed with cosign. Local runs do not build it.
- `scripts/prune_releases.sh`: deletes releases older than `artifact_retention_days`. Runs only from a manual workflow run with `prune_releases` ticked. Try it first with `bash scripts/prune_releases.sh <owner/repo> <days> --dry-run`.
- `scripts/release_local.sh` (Linux and macOS) and `scripts/release_local.bat` (Windows, calls the .sh through Git Bash): local builds. Used only when `build_location` is `local`.
- `packaging/keys/release-signing-public.pem`: public key, only for `ed25519` signing. Never put the private key in the repo.
- `VERSION`: the major version number. The release tag is `v<VERSION>.<yyyymmdd_hhmm>` in UTC. Packages (.deb, .sh, installer, zips) use `<VERSION>.<yyyymmddhhmm>`, so every release is a newer package version. If a tag already exists, the run adds a suffix.
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`: pointers to this file for each agent.

## Release file names
Every file in a release is named `app-<version>-<platform>[-<kind>].<ext>`, with `<version>` = `<VERSION>.<yyyymmddhhmm>`. The build job fails on a file that does not follow it, on pull requests too.
- `app-<version>-windows.exe`: the PyInstaller exe
- `app-<version>-windows-setup.exe`: the Inno Setup installer
- `app-<version>-linux.sh`: the self-extracting Linux installer
- `app-<version>-linux-amd64.deb`: the Debian package
- `app-<version>-linux-install.sh`: the install helper (`scripts/install-linux.sh`)
- `app-<version>-frontend.zip`: the built SPA
- `app-<version>-uv.tar.gz`: the source bundle for uv deploy
- `app-<version>-docker.txt`: the Docker image name, tag and digest (the image itself is in GHCR as `ghcr.io/<owner>/<repo>:<version>`)
- `SHA256SUMS`, and a `.bundle` (cosign) or `.sig` (ed25519) next to each file: these keep their standard names so `sha256sum -c` and the verify commands work unchanged.

## Answers recorded at setup (edit `distribution.json` to change)
The setup agent fills in the "Answer" column from the user's answers and writes the same values into `distribution.json`. A cell that still reads `<fill in>` means the question has not been asked yet.

| # | Question | Answer | Options |
|---|---|---|---|
| Q1 | Language | <fill in> | Python only, Node only, Mix |
| Q2 | Node is a single-page app (SPA)? (Node only) | <fill in> | Yes (static files), No (Node server) |
| Q3 | Python framework and frontend | <fill in> | None, Flask/FastAPI bundled, Flask/FastAPI beside (not built yet), uv deploy |
| Q3 | Frontend bundled in the exe (`bundle_frontend`, `frontend_dir`, `frontend_dist`) | <fill in> | false, or true with the folder and its build output |
| Q4 | Windows .exe (`windows_exe`) | <fill in> | true / false |
| Q4 | Windows Inno Setup installer (`windows_inno_installer`) | <fill in> | true / false |
| Q4 | Linux .sh (`linux_sh`) | <fill in> | true / false |
| Q4 | Linux .deb (`linux_deb`) | <fill in> | true / false |
| Q4 | Node SPA zip (`node_spa_zip`) | <fill in> | true / false |
| Q4 | uv deploy (`uv_deploy`) | <fill in> | true / false |
| Q4 | Docker image to GHCR (`docker`) | <fill in> | true / false |
| Q4b | Build location (`build_location`) | <fill in> | github, local |
| Q5 | Signing (`signing`) | <fill in> | cosign, ed25519 |
| Q6 | Release trigger and publishing | <fill in> | Every merge to main to a releases repo; other options are not built into the template |
| Q7 | Artifact retention (`artifact_retention_days`) | <fill in> | 7 (default), keep everything. Old releases are deleted only by a manual run with `prune_releases` |
| - | App name and entry point (`app_name`, `entry`) | <fill in> | |

## Repos, secrets, folders (fill in for this project)
Fill in every line. The setup agent writes these from the user's answers. Never write a token or key value here.

- Project repo (where the code and workflow live): <fill in: owner/repo>
- Releases repo (public, must have at least one commit): <fill in: owner/repo>, saved as `releases_repo` in `distribution.json`
- Repo variable `RELEASES_REPO` (optional, GitHub runs): <fill in: owner/repo, or "not set" to use `<repo>-releases`>
- Repo secret `RELEASES_REPO_TOKEN`: a fine-grained token with Contents read and write on the releases repo only. Created by the user on GitHub. Its value is never recorded here. Status: <fill in: added / not yet added>
- Docker image (Docker only): <fill in: ghcr.io/owner/repo, and whether the package is public or private, or "not used">. No secret: the workflow uses its own `GITHUB_TOKEN`.
- Repo secret `RELEASE_SIGNING_KEY` (ed25519 only): the whole PEM private key. Its value is never recorded here. Status: <fill in: added / not needed>
- Local working folder (for `build_location: local` only): <fill in: path on the user's machine, or "not used">
- Git and gh on the local machine (local only): <fill in: installed and logged in / not checked>

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
- cosign, release from GitHub Actions (one `.bundle` per file): `cosign verify-blob --bundle <file>.bundle --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com <file>`
- cosign, release made locally (only `SHA256SUMS.bundle`, signed with the person's own login): `cosign verify-blob --bundle SHA256SUMS.bundle --certificate-identity <email used to sign> --certificate-oidc-issuer <issuer> SHA256SUMS`, then `sha256sum -c SHA256SUMS`. The issuer is the one picked at sign-in: `https://github.com/login/oauth`, `https://accounts.google.com` or `https://login.microsoftonline.com`. Record the email and issuer in this file so others can verify.
- ed25519: `openssl pkeyutl -verify -pubin -inkey packaging/keys/release-signing-public.pem -rawin -in <file> -sigfile <file>.sig`
- Docker image, cosign: `cosign verify ghcr.io/<owner>/<repo>@<digest> --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com`, with the digest from `app-<version>-docker.txt`. With ed25519, verify that file's `.sig`; it names the digest.

## Known gotchas (learned the hard way)
- PyInstaller resolves `ENTRY` relative to the spec's folder (`packaging/`).
- Git Bash rewrites arguments that start with `/` into Windows paths, so ISCC sees `/DMyAppVersion=...` as a second script ("You may not specify more than one script filename"). Run ISCC with `MSYS_NO_PATHCONV=1`.
- The publish job must check out the repo, or `scripts/` is missing.
- The publish job waits for the `docker` job. When Docker is off that job is skipped, so publish uses `!cancelled()` and accepts `skipped`; without that, GitHub would skip publish too.
- GHCR image names must be lowercase, so the workflow lowercases `<owner>/<repo>`.
- An empty releases repo fails with HTTP 422 "Repository is empty".
- A 403 from `gh release create` means the token is missing repo access or Contents write.
- Runs on `main` go one after another. GitHub keeps only one waiting run, so a burst of merges comes out as one release built from the newest commit. Pull request runs cancel older runs of the same PR.
- The workflow and `release_local.sh` call scripts from `scripts/`. If one is missing, the build fails with `cp: cannot stat`; run `generate.sh` again.
- Packaging order: the frontend builds first, then PyInstaller, then the Linux `.sh` and `.deb` and the Inno installer. The raw Linux binary is not published; the `.sh` and `.deb` contain it.
- Node 24 is the target. Actions are pinned to Node 24 runtimes (checkout v5, setup-node v5, setup-python v6, upload and download artifact v5). `cosign-installer` is still v3 and not yet checked against Node 24.

## Not done yet (do not assume these work)
- Setup choices not in the template: frontend shipped beside the exe, manual tag releases, keeping artifacts only in Actions, and publishing through `repository_dispatch`.
- The uv deploy bundle is built, but running it on a target has not been tested.
- Docker: the image is Linux amd64 only, and local runs (`release_local.sh`) do not build or push it.
- `prune_releases` has not been run against a real releases repo; use `--dry-run` first.
- Local releases on Windows (Inno Setup through Git Bash) have not been tested end to end.
