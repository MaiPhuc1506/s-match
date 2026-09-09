from fastapi import APIRouter
from app.schemas import MatchRequest, MatchResponse
from app.services.matcher import MatchmakingEngine

router = APIRouter(prefix="/api/v1", tags=["Matchmaking"])

@router.post("/match", response_model=MatchResponse)
def process_matchmaking(request: MatchRequest):
    results = MatchmakingEngine.run_pipeline(
        user=request.current_user,
        candidates=request.candidates,
        limit=request.limit or 10
    )
    return MatchResponse(matched_users=results)