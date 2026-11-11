# Test spec for the Flask sample. Entry point is the sample app.
ENTRY = "../test/samples/flask/app.py"  # relative to packaging/, where this spec lives
# NAME is the release name (app_name in distribution.json), so the build is <app_name>.exe or <app_name>
import json, os
with open(os.path.join(SPECPATH, "..", "distribution.json")) as f:
    NAME = json.load(f).get("app_name") or "app"
DATAS = []
# env_hook.py loads the .env next to the built program (a frozen load_dotenv() looks only in the current folder)
HOOKS = [h for h in [os.path.join(SPECPATH, "env_hook.py")] if os.path.isfile(h)]
a = Analysis([ENTRY], pathex=[".."], datas=DATAS, hiddenimports=[], runtime_hooks=HOOKS)
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, a.binaries, a.datas, [], name=NAME, console=True, onefile=True)
