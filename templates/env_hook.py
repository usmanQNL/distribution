# PyInstaller runtime hook, written by the distribution skill to packaging/env_hook.py; packaging/app.spec uses it.
# In a built (frozen) app, python-dotenv's load_dotenv() looks for .env only in the current folder, which is
# wrong when the program starts from a shortcut, the Start menu or a command on PATH. This hook first loads the
# .env that sits next to the executable. Variables already set in the environment are never changed.
import os
import sys


def _parse(path):
    values = {}
    with open(path, encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if line.startswith("export "):
                line = line[7:].lstrip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = (part.strip() for part in line.split("=", 1))
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'\"":
                value = value[1:-1]
            elif " #" in value:
                value = value.split(" #", 1)[0].rstrip()
            values[key] = value
    return values


def _load_env_beside_executable():
    if not getattr(sys, "frozen", False):
        return
    path = os.path.join(os.path.dirname(os.path.realpath(sys.executable)), ".env")
    if not os.path.isfile(path):
        return
    try:
        from dotenv import load_dotenv  # the app's own parser, when the app uses python-dotenv
    except ImportError:
        for key, value in _parse(path).items():
            os.environ.setdefault(key, value)
    else:
        load_dotenv(path, override=False)


_load_env_beside_executable()
