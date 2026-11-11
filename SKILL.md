---
name: distribution
description: Use when the user wants release builds (Windows .exe, Linux .sh/.deb, a frontend bundle, or a Docker image) with SHA256 checksums and signatures (cosign or Ed25519), published on every merge via GitHub Actions. Asks setup questions first.
license: MIT OR Apache-2.0
---

# Distribution skill

Builds release artifacts on every merge to main and publishes them to a separate public releases repository, following the QuellDAP pattern.

## Step 1: Ask the setup questions

Ask these one at a time. For each question, give the options with a short pro and con, then recommend one. Wait for the answer before moving on. Record every answer in `distribution.json` at the repo root so the scripts can read it.

**Q0. Release name**
Ask what name the release files should carry. Every release file starts with it, for example `<name>-<version>-windows.exe` and `<name>-<version>-linux.sh`. It is also the name of the exe and the Linux command, the install folder and the Start menu entry. Record it as `app_name` in `distribution.json` and in the Q0 row of `distribution.md`.
- **The project name** (default, recommended): `generate.sh` fills in the project folder name. Pro: matches the repo, nothing to remember. Con: a repo name such as `backend` may mean little to the people downloading it.
- **A product name the user picks**, for example `acme-notes`. Pro: users see the name they know. Con: one more thing to change if the product is renamed.

Use letters, digits, `.`, `_` and `-` only, with no spaces, starting with a letter or digit. The build stops on anything else. Lowercase is safest, since Linux commands are case sensitive (the `.deb` package name is lowercased either way).

**Q1. Language of the codebase**
- Python only (PyInstaller)
- Node only (npm run build, then a package)
- Mix: Python backend plus Node frontend (recommended if the app serves a SPA from Python)

**Q2. If Node is used: is it a SPA?**
- Yes: `npm run build` produces static files, which Python or a static host serves. Pro: simple. Con: needs a server at runtime.
- No: a Node server package. Pro: runs on its own. Con: needs Node on the target machine unless bundled.

**Q3. Python web framework (if Python is used)**
- None (CLI or desktop): PyInstaller only.
- Flask or FastAPI, bundle the built frontend inside the executable (recommended): one file runs the whole app. Pro: one artifact. Con: larger file. Set `bundle_frontend: true`, `frontend_dir` (the folder with `package.json`) and `frontend_dist` (its build output, usually `dist`) in `distribution.json`, and add the built folder to `DATAS` in `packaging/app.spec`. The workflow builds the frontend before PyInstaller.
- Flask or FastAPI, ship the frontend beside the executable: smaller build. Con: two folders to keep in sync. Not built into the template yet.
- Deploy with uv on the target instead of PyInstaller: Pro: no binaries to build. Con: the target needs Python and uv.

**Q4. Artifacts, asked one at a time**
Ask about each artifact separately. Only the ones the user says yes to are built. Record each answer as `true` or `false` under `targets` in `distribution.json`.
- **Windows .exe** (`windows_exe`): a single PyInstaller executable. Pro: no install step, runs straight away. Con: no uninstaller or Start menu entry.
- **Windows installer** (`windows_inno_installer`): an Inno Setup setup file built from `packaging/installer.iss`. Pro: Start menu entry, uninstaller and a standard install. Con: needs the .exe too, and the build runs on a Windows runner. Needs Inno Setup 6 (ISCC.exe): see "When the Windows installer is chosen" below.
- **Linux .sh** (`linux_sh`): a self-extracting installer. Pro: runs on any distro. Con: a bit larger, since it bundles the app.
- **Linux .deb** (`linux_deb`): a Debian or Ubuntu package. Pro: installs with apt or dpkg. Con: only for Debian-based systems.
- **Docker image** (`docker`): a `Dockerfile` and `.dockerignore` for the project. Every pull request builds the image as a check. Every merge to main pushes it to GitHub Container Registry as `ghcr.io/<owner>/<repo>:<version>` and `:latest`, signs it with cosign (keyless), and adds `<app_name>-<version>-docker.txt` (the image digest) to the release. Pro: runs the same on any host with Docker, and suits servers. Con: the target needs Docker, the image is Linux amd64 only, and a new GHCR package starts private. Python and Mix projects get the Python file; Node projects get the Node file, which has a `spa` stage (nginx) and a `server` stage (`npm start`): keep the one that matches Q2 and delete the other.
- **Node SPA zip** (`node_spa_zip`): the `npm run build` output zipped, once per release (`<app_name>-<version>-frontend.zip`). Pro: small and simple. Con: needs a server to serve it.
- **uv deploy** (`uv_deploy`): no binary, the target runs the app with uv. The release gets `<app_name>-<version>-uv.tar.gz`, the source at that commit with `scripts/uv-deploy.sh` inside. Pro: no build step. Con: the target needs Python and uv, and the project needs a `pyproject.toml`.

Every release file is named `<app_name>-<version>-<platform>[-<kind>].<ext>` (the list is in `distribution.md`, "Release file names").

Default: only the Windows .exe is on. Each option is a separate choice, and the workflow builds only the ones marked `true`.

**Q4b. Where do builds run?**
Ask this before the signing question.
- **GitHub** (default, `"build_location": "github"`): Actions builds, checksums, signs and publishes on every push to main. Pro: fully automatic, same machine every time, no local tools. Con: needs GitHub minutes and a secret for the releases repo. The Windows installer needs a Windows runner.
- **Local** (`"build_location": "local"`): run `scripts/release_local.sh` (Linux or macOS) or `scripts/release_local.bat` (Windows, through Git Bash) on the user's machine. Pro: no CI setup and no minutes used, and you can test a build before publishing. Con: manual, each OS builds only its own packages, and no Docker image.

**Tell the user before they choose:** for one release with everything (the Windows .exe and installer, the Linux .sh and .deb, and the Docker image), choose **GitHub (Actions)**. Its Windows and Linux runners build every selected target, and it builds and pushes the Docker image, all into a single release. A local run builds only what the machine it runs on can build: Windows gives the .exe and the installer, Linux gives the .sh and the .deb, and macOS gives neither. It never builds or pushes the Docker image. Each local run also publishes its own release, so running it on Windows and then on Linux gives two separate releases, not one combined one. Local suits a quick release for one platform, or testing a build before publishing. Where things go: only the Docker image goes to GitHub Container Registry, and only with GitHub (Actions) builds. On every merge to main the workflow pushes it to `ghcr.io/<owner>/<repo>` (tagged with the version and `latest`), signs it with cosign when signing is cosign, and adds `<app_name>-<version>-docker.txt` with the image digest to the release (with Ed25519, that signed file vouches for the digest). Pull requests only build the image. A new GHCR package starts out private; make it public under the package's settings if anyone should pull it. The Windows and Linux files (.exe, installer, .sh, .deb) are not container images, so they go to the releases repo as a GitHub Release, with `SHA256SUMS` and signatures. A local run never builds Docker, so nothing from it reaches GHCR.

When local is chosen, first check that git is installed (`git --version`). If it isn't, offer to install it and do not run a local release until it is. Also check the GitHub CLI with `bash scripts/ensure_gh.sh --check`. If `gh` is missing, tell the user and offer to install it now with `bash scripts/ensure_gh.sh` (winget or choco on Windows, brew on macOS, the official apt repo or the distro package on Linux); `release_local.sh` also does this before it builds. Then check `gh auth status`. Walk the user through `gh auth login` and `gh auth setup-git` if needed (the steps are in `distribution.md`). Then skip the Actions secret and the workflow steps, and tell the user to run the script on each OS they build for. Record the choice in `distribution.md`.

**When the Windows installer is chosen** (`windows_inno_installer: true`), check that ISCC, the Inno Setup 6 compiler, will be there:
- **GitHub builds:** nothing to install. The workflow runs `scripts/ensure_iscc.sh`, which installs Inno Setup with choco on the Windows runner when it is missing.
- **Local builds on Windows:** run `bash scripts/ensure_iscc.sh --check` in Git Bash. If it reports ISCC missing, tell the user and offer to install it now with `bash scripts/ensure_iscc.sh` (winget, or choco when winget is not there). `release_local.sh` also runs this before it builds anything and installs Inno Setup if needed, so a release never fails halfway on a missing ISCC.
- **Local builds on Linux or macOS:** Inno Setup does not run there. Tell the user the installer can be built only on Windows (`scripts\release_local.bat`) or on GitHub, and that the local run skips it.

**Q5. Checksums and signing**
SHA256SUMS is always written. Signing is required, and the user picks one of these two. Record the choice as `signing` in `distribution.json`.
- **cosign** (default, `"signing": "cosign"`): Sigstore keyless signing. Pro: no key to store or lose, and the signature is tied to the GitHub workflow identity. Con: needs `id-token: write` and verification needs the cosign tool.
- **ed25519** (`"signing": "ed25519"`): a signature per file made with your own Ed25519 key. Pro: works offline, no Sigstore dependency, and verification needs only OpenSSL. Con: you must keep the private key safe. It lives in the `RELEASE_SIGNING_KEY` secret, and if it leaks you must rotate it.

**Q6. Release trigger and publishing**
- Every merge to main creates a release (recommended, matches QuellDAP). Tag: `v<major>.yyyymmdd_hhmm` (UTC), with the major number read from a VERSION file. Packages (.deb, .sh, installer) use `<major>.yyyymmddhhmm`, so each release is a newer package version. Runs go one at a time; if several merges land while one runs, GitHub keeps only the newest waiting run, so they come out as one release built from the newest commit.
- Manual tag only. Pro: fewer releases. Con: someone must remember to tag. Not built into the template yet.
- Publish to a separate public releases repository (recommended). The workflow uploads the files with `gh release create` using a token secret. A `repository_dispatch` option is not built yet.
- Keep artifacts only in this repo's Actions artifacts. Pro: no second repo. Con: not public. Not built into the template yet.

**Q7. Artifact retention**
- Keep 7 days of Actions artifacts (recommended). Build artifacts are deleted as soon as a publish succeeds, since the release holds the files; the 7 days cover pull request builds and failed publishes.
- Delete old releases too (opt-in): a manual run with `prune_releases` ticked deletes releases older than `artifact_retention_days`. It never runs on its own.
- Keep everything. Con: storage grows.

## Step 2: Generate

After the answers are saved in `distribution.json`:

1. Run `scripts/detect.sh <project-dir>` to confirm the language and Python framework. It prints `language=` (node, python, mix), `python_framework=` (flask, fastapi, streamlit or none) and `uses_env=` (yes when the app reads a `.env` file). When `uses_env=yes`, tell the user that every release will ship a settings template, `<app_name>-<version>-env.example`, and say where `.env` goes for each artifact they chose (the table in `distribution.md`, "Settings file (.env)"). No question is needed.
2. Run `scripts/generate.sh <project-dir>` to write:
   - `.github/workflows/release.yml`, copied from `templates/release.yml`
   - `distribution.json`, copied from `templates/distribution.json`, unless the project already has one, with `app_name` set to the project folder name. Set `app_name` to the Q0 answer, and the `targets` flags and the frontend keys from the answers.
   - `packaging/app.spec` and `packaging/installer.iss`, unless the project already has them
   - `scripts/`: `checksums.sh`, `sign.sh`, `env_example.sh`, `make_sh.sh`, `make_deb.sh`, `prune_releases.sh`, `install-linux.sh`, `uv-deploy.sh`, `ensure_iscc.sh` and `ensure_gh.sh`. The workflow calls them.
   - `Dockerfile` and `.dockerignore`, only when `targets.docker` is true and the project has none yet: `templates/Dockerfile.python` for Python or Mix, `templates/Dockerfile.node` for Node. If `docker` was set to true after the first run, run `generate.sh` again; it keeps files that already exist.
   - `distribution.md` and the `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` pointers
   - `packaging/env_hook.py`, the PyInstaller runtime hook that loads the `.env` next to the built program (a frozen `load_dotenv()` looks only in the current folder). `templates/app.spec` lists it in `HOOKS`; a project that already had a spec needs that line added.
   - `.env.example`, only when the app reads a `.env` and the project has a `.env` but no template: a copy with every value removed. Have the user check it and commit it. `generate.sh` also adds `.env` to `.gitignore`, and warns if `.env` is already committed (then tell the user to remove it and rotate its secrets). If the app reads a `.env` but has neither file, write `.env.example` yourself with the variable names the code reads and no values. Never ship or commit the real `.env`.
3. Write the answers and repo details into the project's `distribution.md` (copied from `templates/distribution.md`). Fill in every `<fill in>` cell: the answers, the repos, the secrets' status and the local folder. Never write a token or key value. Keep it current whenever an answer changes. It is the agent-neutral record, so a new agent from any provider can run the release cycle from it. A record with any `<fill in>` left is not finished.
4. Tell the user which files were written and what to commit. The user commits and pushes; this skill does not push.

The Python spec needs its entry point and any built frontend filled in. Fill in `ENTRY` and `DATAS` for the project.

If Docker was chosen, fill in the Dockerfile too: pick the `CMD` line for the framework (the template lists CLI, Flask, FastAPI and Streamlit) and set `EXPOSE`. For a Mix project with a bundled frontend, uncomment the `frontend` stage and its `COPY --from` line. For Node, delete the stage that does not match Q2. Check it locally with `docker build -t app .` and `docker run --rm -p 8000:8000 app` when Docker is installed.

The `test/samples/` folder has a HelloWorld app for node, python-uv, flask, streamlit and fastapi. Use them to check the templates before a real project.

## Step 3: Set up GitHub Actions for every merge

Only for `build_location: github`. For local builds, skip this step and give the user the `scripts/release_local.bat` (Windows) or `scripts/release_local.sh` (Linux or macOS) run instructions from `distribution.md`.

Walk the user through this, one step at a time. Wait for confirmation before the next step.

1. **Push the generated files.** The user commits and pushes `.github/workflows/release.yml`, `packaging/` and `scripts/`.
2. **Create the releases repository** (if Q6 chose one). It must be public. Name it `<repo>-releases`.
3. **Create a token for publishing.** A fine-grained personal access token with Contents read and write on the releases repo only. Copy it into the codebase repo as the Actions secret `RELEASES_REPO_TOKEN`: Settings, Secrets and variables, Actions, New repository secret. The token value must never be committed to the repo or pasted into chat.
3b. **Set the releases repo name (optional).** Settings, Secrets and variables, Actions, Variables, New repository variable: name `RELEASES_REPO`, value `<owner>/<releases-repo>`. Without it the workflow uses `<repo>-releases`.
4. **Allow the workflow to sign.** Settings, Actions, General: set Workflow permissions to read. The template already grants `id-token: write`, which cosign needs.
   - **If cosign:** no key to store.
   - **If ed25519:** generate a key pair on your own machine, then put only the public half in the repo:
     ```
     openssl genpkey -algorithm ed25519 -out release-signing-private.pem
     mkdir -p packaging/keys
     openssl pkey -in release-signing-private.pem -pubout -out packaging/keys/release-signing-public.pem
     ```
     Commit `packaging/keys/release-signing-public.pem`. Add the private file to the repo secrets as `RELEASE_SIGNING_KEY` (paste the whole PEM contents), then delete the local private file or keep it somewhere safe. Never commit it. The workflow checks the secret before it builds (set, Ed25519, matches the public key) and stops a release from main if it is missing or wrong. For local builds, have the user `export RELEASE_SIGNING_KEY=<path to the private file>`, and check it with `bash scripts/sign.sh - check-key packaging/keys/release-signing-public.pem`.
5. **Turn on branch protection for main.** The release workflow runs its build jobs on every pull request (it publishes only from main). Require `build (ubuntu-latest)` and `build (windows-latest)` to pass before merge, and `docker` too if Docker was chosen, so a broken build cannot merge.
5b. **Docker only: nothing to create.** The workflow pushes with its own `GITHUB_TOKEN` (`packages: write`), so no secret is needed. After the first merge, the image is under the repo's Packages. GHCR makes a new package private; to let anyone pull it, open the package, Package settings, Change visibility, Public.
6. **Trigger the first run.** Merge a small change to main, or use the Actions tab, Run workflow. Open the run and check each job is green.
7. **Verify the release.** Download the artifacts, `SHA256SUMS`, and the signature files (`.bundle` for cosign, `.sig` for ed25519). Then:
   - Checksums: `sha256sum -c SHA256SUMS`
   - If cosign: `cosign verify-blob --bundle <file>.bundle --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com <file>`
   - If cosign and the release was made locally: only `SHA256SUMS` is signed, with the person's own identity. See "Verify a release" in `distribution.md`.
   - If ed25519: `openssl pkeyutl -verify -pubin -inkey packaging/keys/release-signing-public.pem -rawin -in <file> -sigfile <file>.sig`
   - If Docker: `docker pull` the digest from `<app_name>-<version>-docker.txt`, then (cosign) `cosign verify ghcr.io/<owner>/<repo>@<digest> --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com`. With ed25519 the signed `<app_name>-<version>-docker.txt` vouches for the digest.

For each step, the skill says what to click and what a green result looks like. If a step fails, the skill reads the log and suggests the fix. It does not guess at the secret name or token scope.

Local checks, when possible: `pyinstaller --noconfirm --distpath build/dist --workpath build/work packaging/app.spec` for the Python build. Windows-only installers cannot be built on Linux, so report those as checked only in Actions.

## Rules

- Ask before assuming. Q0 to Q4 are always asked.
- Keep each script small. Automate the rest.
- On Windows, run the skill's `.sh` scripts with Git's own `bash.exe` (in the `bin` folder of the Git install that `where git` points to), or from a Git Bash window. Never call a bare `bash` from cmd or PowerShell: it is often WSL's bash from `Windows\System32`, which runs in Linux and cannot see Windows tools such as ISCC or winget.
- Never write secrets into the repo. Use GitHub Actions secrets such as `RELEASES_REPO_TOKEN`.
- Never ship or commit a real `.env`. Releases ship only `.env.example` (values removed).
- Never include a model name in generated commit messages or artifacts.
