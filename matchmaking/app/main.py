from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, field_validator
from typing import List, Optional, Dict, Any, Union
import numpy as np

app = FastAPI(
    title="S-Match Matchmaking Engine API",
    description="Microservice for multi-factor player matching (Module M4)",
    version="1.1.0"
)

class Point(BaseModel):
    latitude: float = 16.0544
    longitude: float = 108.2022

class UserProfile(BaseModel):
    user_id: str
    skill: Optional[Union[List[float], Dict[str, Any]]] = None
    skills: Optional[List[float]] = None
    available_time_slots: List[str] = []
    location: Optional[Point] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    max_distance_km: Optional[float] = 20.0
    playing_style: List[str] = []
    reliability_score: float = 5.0

    @field_validator('skills', mode='before')
    def parse_skills(cls, v, info):
        raw_skill = v if v is not None else info.data.get('skill')
        
        if isinstance(raw_skill, dict):
            return [
                float(raw_skill.get('smash', 3.0)),
                float(raw_skill.get('defense', 3.0)),
                float(raw_skill.get('net_play', 3.0)),
                float(raw_skill.get('stamina', 3.0)),
                float(raw_skill.get('footwork', 3.0)),
                float(raw_skill.get('serve', 3.0))
            ]
        elif isinstance(raw_skill, list):
            return [float(x) for x in raw_skill]
        return v

class MatchRequestPayload(BaseModel):
    current_user: Optional[UserProfile] = None
    host: Optional[UserProfile] = None
    candidates: List[UserProfile] = []
    limit: Optional[int] = 5

class DistanceRequestPayload(BaseModel):
    point_a: Optional[Point] = None
    point_b: Optional[Point] = None
    lat1: Optional[float] = None
    lon1: Optional[float] = None
    lat2: Optional[float] = None
    lon2: Optional[float] = None

def calculate_haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)
    a = np.sin(dlat / 2)**2 + np.cos(np.radians(lat1)) * np.cos(np.radians(lat2)) * np.sin(dlon / 2)**2
    c = 2 * np.arcsin(np.sqrt(a))
    return float(R * c)

@app.post("/api/v1/distance")
@app.post("/distance")
def api_calculate_distance(payload: DistanceRequestPayload):
    lat1 = payload.lat1 if payload.lat1 is not None else (payload.point_a.latitude if payload.point_a else 16.0544)
    lon1 = payload.lon1 if payload.lon1 is not None else (payload.point_a.longitude if payload.point_a else 108.2022)
    lat2 = payload.lat2 if payload.lat2 is not None else (payload.point_b.latitude if payload.point_b else 16.0544)
    lon2 = payload.lon2 if payload.lon2 is not None else (payload.point_b.longitude if payload.point_b else 108.2022)

    dist = calculate_haversine(lat1, lon1, lat2, lon2)
    return {
        "distance_km": round(dist, 2),
        "unit": "km"
    }

@app.post("/api/v1/match")
@app.post("/match")
def finalize_matchmaking(payload: MatchRequestPayload):
    user = payload.current_user if payload.current_user is not None else payload.host
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error: Host skill profile is incomplete. Exactly 6 performance metrics are required."
        )

    # Lấy danh sách kỹ năng sau khi đã qua validator
    skills_list = user.skills
    
    # Kiểm tra nếu truyền dạng object 'skill' thì lấy từ dict ra list 6 phần tử
    if not skills_list and isinstance(user.skill, dict):
        skills_list = [
            float(user.skill.get('smash', 3.0)),
            float(user.skill.get('defense', 3.0)),
            float(user.skill.get('net_play', 3.0)),
            float(user.skill.get('stamina', 3.0)),
            float(user.skill.get('footwork', 3.0)),
            float(user.skill.get('serve', 3.0))
        ]

    # Kiểm tra nghiêm ngặt: Nếu không đủ đúng 6 phần tử sẽ báo lỗi 400
    if not skills_list or len(skills_list) != 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error: Host skill profile is incomplete. Exactly 6 performance metrics are required."
        )

    candidates = payload.candidates
    if not candidates:
        if payload.current_user is not None:
            return {
                "total_candidates_processed": 0,
                "matched_users": []
            }
        return []

    matched_users = []
    
    u_lat = user.location.latitude if user.location else (user.lat if user.lat else 16.0544)
    u_lon = user.location.longitude if user.location else (user.lon if user.lon else 108.2022)
    max_allowed_dist = user.max_distance_km if user.max_distance_km is not None else 20.0
    user_skills_arr = np.array(skills_list)

    for cand in candidates:
        c_lat = cand.location.latitude if cand.location else (cand.lat if cand.lat else 16.0544)
        c_lon = cand.location.longitude if cand.location else (cand.lon if cand.lon else 108.2022)

        dist = calculate_haversine(u_lat, u_lon, c_lat, c_lon)
        
        cand_max_dist = cand.max_distance_km if cand.max_distance_km is not None else 20.0
        if dist > max_allowed_dist or dist > cand_max_dist:
            continue

        cand_skills = cand.skills
        if not cand_skills and isinstance(cand.skill, dict):
            cand_skills = [
                float(cand.skill.get('smash', 3.0)),
                float(cand.skill.get('defense', 3.0)),
                float(cand.skill.get('net_play', 3.0)),
                float(cand.skill.get('stamina', 3.0)),
                float(cand.skill.get('footwork', 3.0)),
                float(cand.skill.get('serve', 3.0))
            ]
        elif not cand_skills:
            cand_skills = [3.0] * 6

        cand_skills_arr = np.array(cand_skills)

        skill_similarity = max(0.0, 1.0 - (np.linalg.norm(user_skills_arr - cand_skills_arr) / 10.0))
        distance_score = max(0.0, 1.0 - (dist / max_allowed_dist)) * 100.0
        
        total_score = float((skill_similarity * 0.3 + (distance_score / 100.0) * 0.25 + 0.45) * 100)

        matched_users.append({
            "user_id": cand.user_id,
            "match_score": round(total_score, 2),
            "distance_km": round(dist, 2),
            "breakdown": {
                "distance_score": round(distance_score, 2),
                "skill_score": round(skill_similarity * 100, 2)
            }
        })

    matched_users.sort(key=lambda x: (-x["match_score"], x["distance_km"]))
    
    if payload.limit:
        matched_users = matched_users[:payload.limit]

    if payload.current_user is not None:
        return {
            "total_candidates_processed": len(candidates),
            "matched_users": matched_users
        }
    else:
        return matched_users