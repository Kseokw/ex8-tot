from datetime import datetime, timezone
import socket

from fastapi import FastAPI

app = FastAPI(title="company-backend")


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.get("/api/hello")
def hello():
    return {
        "message": "Hello from FastAPI",
        "pod": socket.gethostname(),
        "time": datetime.now(timezone.utc).isoformat(),
    }
