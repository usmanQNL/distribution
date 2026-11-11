---
name: distribution
description: Use when the user wants release builds (Windows .exe, Linux .sh/.deb, or a frontend bundle) with SHA256 checksums and signatures (cosign or Ed25519), published on every merge via GitHub Actions. Asks setup questions first.
---

# Distribution skill

Builds release artifacts on every merge to main and publishes them to a separate public releases repository, following the QuellDAP pattern.

## Step 1: Ask the setup questions

Ask these one at a time. For each question, give the options with a short pro and con, then recommend one. Wait for the answer before moving on. Record every answer in `distribution.json` at the repo root so the scripts can read it.

**Q1. Language of the codebase**
- Python only (PyInstaller)
- Node only (npm run build, then a package)
- Mix: Python backend plus Node frontend (recommended if the app serves a SPA from Python)

**Q2. If Node is used: is it a SPA?**
- Yes: `npm run build` produces static files, which Python or a static host serves. Pro: simple. Con: needs a server at runtime.
- No: a Node server package. Pro: runs on its own. Con: needs Node on the target machine unless bundled.

**Q3. Python web framework (if Python is used)**
- None (CLI or desktop): PyInstaller only.
- Flask or FastAPI, bundle the built frontend inside the executable (recommended): one file runs the whole app. Pro: one artifact. Con: larger file.
- Flask or FastAPI, ship the frontend beside the executable: smaller build. Con: two folders to keep in sync.
- Deploy with uv on the target instead of PyInstaller: Pro: no binaries to build. Con: the target needs Python and uv.

**Q4. Artifacts, asked one at a time**
Ask about each artifact separately. Only the ones the user says yes to are built. Record each answer as `true` or `false` under `targets` in `distribution.json`.
- **Windows .exe** (`windows_exe`): a single PyInstaller executable. Pro: no install step, runs straight away. Con: no uninstaller or Start menu entry.
- **Windows installer** (`windows_inno_installer`): an Inno Setup setup file built from `packaging/installer.iss`. Pro: Start menu entry, uninstaller and a standard install. Con: needs the .exe too, and the build runs on a Windows runner.
- **Linux .sh** (`linux_sh`): a self-extracting installer. Pro: runs on any distro. Con: a bit larger, since it bundles the app.
- **Linux .deb** (`linux_deb`): a Debian or Ubuntu package. Pro: installs with apt or dpkg. Con: only for Debian-based systems.
- **Node SPA zip** (`node_spa_zip`): the `npm run build` output zipped. Pro: small and simple. Con: needs a server to serve it.
- **uv deploy** (`uv_deploy`): no binary, the target runs the app with uv. Pro: no build step. Con: the target needs Python and uv. Copies `templates/uv-deploy.sh`.

Default: only the Windows .exe is on. Each option is a separate choice, and the workflow builds only the ones marked `true`.

**Q5. Checksums and signing**
SHA256SUMS is always written. Signing is required, and the user picks one of these two. Record the choice as `signing` in `distribution.json`.
- **cosign** (default, `"signing": "cosign"`): Sigstore keyless signing. Pro: no key to store or lose, and the signature is tied to the GitHub workflow identity. Con: needs `id-token: write` and verification needs the cosign tool.
- **ed25519** (`"signing": "ed25519"`): a signature per file made with your own Ed25519 key. Pro: works offline, no Sigstore dependency, and verification needs only OpenSSL. Con: you must keep the private key safe. It lives in the `RELEASE_SIGNING_KEY` secret, and if it leaks you must rotate it.

**Q6. Release trigger and publishing**
- Every merge to main creates a release (recommended, matches QuellDAP). Version: `v<major>.yyyymmdd_hhmm` (UTC), with the major number read from a VERSION file.
- Manual tag only. Pro: fewer releases. Con: someone must remember to tag.
- Publish to a separate public releases repository (recommended). The workflow sends a `repository_dispatch` or copies the files using a token secret.
- Keep artifacts only in this repo's Actions artifacts. Pro: no second repo. Con: not public.

**Q7. Artifact retention**
- Keep 7 days of Actions artifacts and prune older release runs (recommended).
- Keep everything. Con: storage grows.

## Step 2: Generate

After the answers are saved in `distribution.json`:

1. Run `scripts/detect.sh <project-dir>` to confirm the language and Python framework. It prints `language=` (node, python, mix) and `python_framework=` (flask, fastapi, streamlit or none).
2. Run `scripts/generate.sh <project-dir>` to write:
   - `.github/workflows/release.yml`, copied from `templates/release.yml`
   - `distribution.json`, copied from `templates/distribution.json`, unless the project already has one. Set the `targets` flags from the answers.
   - `packaging/app.spec` and `packaging/installer.iss`, unless the project already has them
3. Copy `scripts/checksums.sh` and `scripts/sign.sh` into the project's `scripts/` folder. The release workflow calls them.
4. Write the answers and repo details into the project's `distribution.md` (copied from `templates/distribution.md`). Keep it current whenever an answer changes. It is the agent-neutral record, so a new agent from any provider can run the release cycle from it.
5. Tell the user which files were written and what to commit. The user commits and pushes; this skill does not push.

The Python spec needs its entry point and any built frontend filled in. Fill in `ENTRY` and `DATAS` for the project.

The `test/samples/` folder has a HelloWorld app for node, python-uv, flask, streamlit and fastapi. Use them to check the templates before a real project.

## Step 3: Set up GitHub Actions for every merge

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
     Commit `packaging/keys/release-signing-public.pem`. Add the private file to the repo secrets as `RELEASE_SIGNING_KEY` (paste the whole PEM contents), then delete the local private file or keep it somewhere safe. Never commit it.
5. **Turn on branch protection for main.** Require the release workflow to pass before merge, so a broken build cannot merge.
6. **Trigger the first run.** Merge a small change to main, or use the Actions tab, Run workflow. Open the run and check each job is green.
7. **Verify the release.** Download the artifacts, `SHA256SUMS`, and the signature files. Then:
   - Checksums: `sha256sum -c SHA256SUMS`
   - If cosign: `cosign verify-blob --certificate <file>.pem --signature <file>.sig --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com <file>`
   - If ed25519: `openssl pkeyutl -verify -pubin -inkey packaging/keys/release-signing-public.pem -rawin -in <file> -sigfile <file>.sig`

For each step, the skill says what to click and what a green result looks like. If a step fails, the skill reads the log and suggests the fix. It does not guess at the secret name or token scope.

Local checks, when possible: `pyinstaller --noconfirm packaging/app.spec` for the Python build. Windows-only installers cannot be built on Linux, so report those as checked only in Actions.

## Rules

- Ask before assuming. Q1 to Q4 are always asked.
- Keep each script small. Automate the rest.
- Never write secrets into the repo. Use GitHub Actions secrets such as `RELEASES_REPO_TOKEN`.
- Never include a model name in generated commit messages or artifacts.
