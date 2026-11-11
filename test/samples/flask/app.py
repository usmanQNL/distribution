import os

from dotenv import load_dotenv
from flask import Flask

load_dotenv()  # reads .env; a built exe also reads the .env next to it (packaging/env_hook.py)
app = Flask(__name__)

@app.get("/")
def index():
    return os.environ.get("GREETING", "Hello from Flask")

if __name__ == "__main__":
    app.run()
