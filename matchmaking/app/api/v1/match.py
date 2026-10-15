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


@router.post(
    "/match",
    response_model=MatchmakingResponse,
    status_code=status.HTTP_200_OK,
)
async def find_players(payload: MatchmakingRequest):
  """Nhận thông tin người chơi & danh sách ứng viên, chạy bộ lọc cứng & thuật

  toán tính điểm tương thích.
  """
  limit = payload.limit or 5
  return MatchmakingEngine.run_pipeline(
      current_user=payload.current_user,
      candidates=payload.candidates,
      limit=limit,
      return_response_model=True,  # BẮT BUỘC: Thêm tham số này
  )


@router.post(
    "/distance", response_model=DistanceResponse, status_code=status.HTTP_200_OK
)
async def calculate_distance(payload: DistanceRequest):
  dist = calculate_player_to_player_distance(payload.point_a, payload.point_b)
  return DistanceResponse(
      distance_km=dist,
      unit="km",
  )