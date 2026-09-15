from fastapi import FastAPI
from app.api.v1.match import router as match_router

app = FastAPI(title="S-Match Matchmaking Engine")

app.include_router(match_router, prefix="/api/v1")