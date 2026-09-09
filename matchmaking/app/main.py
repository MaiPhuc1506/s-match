from fastapi import FastAPI, status
from app.api.v1.match import router as match_router

app = FastAPI(title="Matchmaking Service", version="1.0.0")

@app.get("/health", status_code=status.HTTP_200_OK, tags=["Health"])
def health_check():
    return {"status": "healthy", "service": "matchmaking"}

app.include_router(match_router)