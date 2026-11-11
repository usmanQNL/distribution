# PyInstaller spec template. generate.sh copies it to packaging/app.spec.
# ENTRY is resolved relative to the spec file folder (packaging/), so use ../ paths from there.
# Replace ENTRY with your entry script, and add frontend folders to DATAS if you bundle a SPA.
# Build: pyinstaller --noconfirm packaging/app.spec
ENTRY = "main.py"          # e.g. "app/main.py" for FastAPI, "app.py" for Flask or Streamlit
# NAME is the release name (app_name in distribution.json), so the build is <app_name>.exe or <app_name>
import json, os
with open(os.path.join(SPECPATH, "..", "distribution.json")) as f:
    NAME = json.load(f).get("app_name") or "app"
DATAS = []                 # e.g. [("frontend/dist", "frontend/dist")] to bundle a built SPA
# env_hook.py loads the .env next to the built program (a frozen load_dotenv() looks only in the current folder)
HOOKS = [h for h in [os.path.join(SPECPATH, "env_hook.py")] if os.path.isfile(h)]

a = Analysis([ENTRY], pathex=["."], datas=DATAS, hiddenimports=[], runtime_hooks=HOOKS)
pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, a.binaries, a.datas, [],
    name=NAME, console=True, onefile=True,
)
