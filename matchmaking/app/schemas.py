from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class SkillPreference(BaseModel):
    level: int = Field(..., ge=1, le=5)
    preferred_min: int = Field(..., ge=1, le=5)
    preferred_max: int = Field(..., ge=1, le=5)

class Location(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)

class PlayerProfileInput(BaseModel):
    user_id: str
    skill: SkillPreference
    available_time_slots: List[datetime]
    location: Location
    playing_style: List[str] = []
    reliability_score: float = Field(5.0, ge=0.0, le=5.0)

class MatchmakingRequest(BaseModel):
    current_user: PlayerProfileInput
    candidates: List[PlayerProfileInput]
    limit: Optional[int] = Field(5, ge=1, le=20)

class BreakdownScores(BaseModel):
    skill_score: float
    time_score: float
    distance_score: float
    style_score: float
    reliability_score: float

class MatchedUserResult(BaseModel):
    user_id: str
    match_score: float
    breakdown: Optional[BreakdownScores] = None

class MatchmakingResponse(BaseModel):
    matched_users: List[MatchedUserResult]
    total_candidates_processed: int