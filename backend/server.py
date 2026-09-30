from fastapi import FastAPI

app = FastAPI(
    title="Stackly Auth API",
    version="1.0.0"
)


@app.get("/")
def home():
    return {
        "message": "I love anna!"
    }


@app.get("/api/health")
def health_check():
    return {
        "status": "ok",
        "message": "Backend is running"
    }