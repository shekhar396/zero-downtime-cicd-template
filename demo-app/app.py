import os

from fastapi import FastAPI


app = FastAPI()


@app.get("/")
def read_root():
    return {
        "application": "demo-app",
        "project": "zero-downtime-cicd-template",
        "version": os.getenv("APP_VERSION", "v1"),
    }


@app.get("/health")
def read_health():
    return {"status": "healthy"}
