from fastapi import APIRouter, status
from app.schemas import MatchmakingRequest, MatchmakingResponse

router = APIRouter()

@router.post("/match", response_model=MatchmakingResponse, status_code=status.HTTP_200_OK)
async def find_players(payload: MatchmakingRequest):
    return MatchmakingResponse(
        matched_users=[],
        total_candidates_processed=len(payload.candidates)
    )