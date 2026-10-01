from fastapi import FastAPI
from app.api.v1.match import router as match_router
from app.api.v1.dataset import router as dataset_router

app = FastAPI(title="S-Match Matchmaking Engine")

# Include các routers
app.include_router(match_router, prefix="/api/v1")
app.include_router(dataset_router)