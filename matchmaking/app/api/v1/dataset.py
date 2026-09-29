from typing import List
from fastapi import APIRouter
from app.schemas import PlayerProfileInput
from app.services.dataset_generator import generate_sample_players

router = APIRouter(prefix="/api/v1/dataset", tags=["Dataset"])


@router.get("/players", response_model=List[PlayerProfileInput])
def get_mock_players():
  """Lấy danh sách Player mẫu dùng cho kiểm thử End-to-End"""
  return generate_sample_players()