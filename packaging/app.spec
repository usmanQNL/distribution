# Test spec for the Flask sample. Entry point is the sample app.
ENTRY = "../test/samples/flask/app.py"  # relative to packaging/, where this spec lives
NAME = "app"
DATAS = []
a = Analysis([ENTRY], pathex=[".."], datas=DATAS, hiddenimports=[])
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, a.binaries, a.datas, [], name=NAME, console=True, onefile=True)
