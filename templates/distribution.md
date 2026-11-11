# Distribution (agent-neutral guide)

Read this file first if you are asked to build, sign or publish release artifacts for this project. It is written so any agent (any model provider) can run the release cycle from scratch.

## What this does
On every push to `main` (and on manual run), GitHub Actions builds the selected artifacts, writes `SHA256SUMS`, signs them, and publishes a GitHub release to a separate public releases repository.

## Files in this project
- `distribution.json`: the answers. Language, entry point, selected artifacts, signing mode. Edit this to change what is built.
- `.github/workflows/release.yml`: the workflow. Do not edit unless changing the pipeline.
- `packaging/app.spec`: PyInstaller spec. `ENTRY` is relative to `packaging/`, so use `../` for paths from the repo root.
- `packaging/installer.iss`: Inno Setup script, used only when `windows_inno_installer` is true.
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
| Signing | `cosign` (default) | `cosign` or `ed25519` |
| Trigger | every merge to main, plus manual run | |
| Publish | separate public releases repo | |
| Artifact retention | 7 days (intended; not implemented in the template yet) | |

## Repos, secrets, folders (as used in this project)
- Skill source: `usmanQNL/distribution` (local: `C:\development\claudeCode\skills\distribution`).
- Releases repo for tests: `usmanQNL/distribution-test` (must not be empty: it needs at least one commit before a release can be created).
- Repo variable (optional): `RELEASES_REPO` = `<owner>/<releases-repo>`. If unset, the workflow uses `<repo>-releases`.
- Repo secret: `RELEASES_REPO_TOKEN`. A fine-grained token: resource owner `usmanQNL`, repository access selected to the releases repo only, Contents read and write. Created on GitHub under Settings, Developer settings, Personal access tokens, Fine-grained tokens. Never commit it or paste it in chat.
- Repo secret (ed25519 only): `RELEASE_SIGNING_KEY`, the whole PEM private key.
- Local QuellDAP working folder (the source project for the first real use): `C:\development\claudeCode\quelldap`.

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
- cosign: `cosign verify-blob --certificate <file>.pem --signature <file>.sig --certificate-identity-regexp "https://github.com/<owner>/<repo>/" --certificate-oidc-issuer https://token.actions.githubusercontent.com <file>`
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
