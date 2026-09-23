from fastapi import APIRouter, status
from app.schemas import (
    MatchmakingRequest,
    MatchmakingResponse,
    DistanceRequest,
    DistanceResponse,
)
from app.services.matcher import MatchmakingEngine
from app.services.distance import calculate_player_to_player_distance

router = APIRouter()


@router.post("/match", response_model=MatchmakingResponse, status_code=status.HTTP_200_OK)
async def find_players(payload: MatchmakingRequest):
    """
    Nhận thông tin người chơi & danh sách ứng viên,
    chạy bộ lọc & thuật toán tính điểm tương thích (kết hợp khoảng cách Haversine).
    """
    limit = payload.limit or 5
    matched_results = MatchmakingEngine.run_pipeline(
        user=payload.current_user,
        candidates=payload.candidates,
        limit=limit,
    )
    return MatchmakingResponse(
        matched_users=matched_results,
        total_candidates_processed=len(payload.candidates),
    )


@router.post("/distance", response_model=DistanceResponse, status_code=status.HTTP_200_OK)
async def calculate_distance(payload: DistanceRequest):
    """
    Endpoint trực tiếp nhận 2 toạ độ địa lý (Player-Player hoặc Player-Court)
    và tính khoảng cách chính xác theo Haversine (km).
    """
    dist = calculate_player_to_player_distance(payload.point_a, payload.point_b)
    return DistanceResponse(
        distance_km=dist,
        unit="km",
    )