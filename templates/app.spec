# PyInstaller spec template. generate.sh copies it to packaging/app.spec.
# ENTRY is resolved relative to the spec file folder (packaging/), so use ../ paths from there.
# Replace ENTRY with your entry script, and add frontend folders to DATAS if you bundle a SPA.
# Build: pyinstaller --noconfirm packaging/app.spec
ENTRY = "main.py"          # e.g. "app/main.py" for FastAPI, "app.py" for Flask or Streamlit
NAME = "app"
DATAS = []                 # e.g. [("frontend/dist", "frontend/dist")] to bundle a built SPA

a = Analysis([ENTRY], pathex=["."], datas=DATAS, hiddenimports=[])
pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, a.binaries, a.datas, [],
    name=NAME, console=True, onefile=True,
)
