from pydantic import BaseModel
from typing import List, Optional

class PlayerProfile(BaseModel):
    user_id: str
    skill_level: int           # Trình độ: 1 (Mới chơi) -> 5 (Vận động viên/Chuyên nghiệp)
    preferred_skill_min: int   # Trình độ đối thủ mong muốn (Min)
    preferred_skill_max: int   # Trình độ đối thủ mong muốn (Max)
    available_time_slots: List[str] # Khung giờ rảnh (vd: ["2026-09-07T18:00", "2026-09-07T20:00"])
    location_x: float          # Vị trí tọa độ
    location_y: float
    playing_style: List[str]   # Phong cách: ["Tấn công", "Phòng thủ", "Đôi nam nữ"]
    reliability_score: float   # Điểm uy tín cộng đồng (Post-match feedback): 0.0 -> 5.0

class MatchRequest(BaseModel):
    current_user: PlayerProfile
    candidates: List[PlayerProfile]
    limit: Optional[int] = 10

class MatchResult(BaseModel):
    user_id: str
    score: float
    reasons: List[str]

class MatchResponse(BaseModel):
    matched_users: List[MatchResult]