import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

@pytest.fixture
def sample_payload():
    return {
        "host": {
            "user_id": "host_01",
            "lat": 16.0544,
            "lon": 108.2022,
            "skills": [4.0, 3.5, 4.0, 3.0, 4.5, 3.5],
            "reliability_score": 4.5,
            "playing_style": ["Aggressive"],
            "available_hours": [18, 19, 20]
        },
        "candidates": [
            {
                "user_id": "cand_near_perfect",
                "lat": 16.0580,
                "lon": 108.2050,
                "skills": [4.0, 3.5, 4.0, 3.0, 4.5, 3.5],
                "reliability_score": 5.0,
                "playing_style": ["Aggressive"],
                "available_hours": [18, 19]
            },
            {
                "user_id": "cand_far_away",
                "lat": 16.5000, # > 20km
                "lon": 108.9000,
                "skills": [4.0, 3.5, 4.0, 3.0, 4.5, 3.5],
                "reliability_score": 5.0,
                "playing_style": ["Aggressive"],
                "available_hours": [18, 19]
            }
        ],
        "limit": 5
    }

def test_5_factor_breakdown_and_filtering(sample_payload):
    response = client.post("/api/v1/match", json=sample_payload)
    assert response.status_code == 200
    data = response.json()
    
    # Verify candidate > 20km bị loại
    user_ids = [item["user_id"] for item in data]
    assert "cand_far_away" not in user_ids
    assert "cand_near_perfect" in user_ids
    
    # Verify đủ 5 chỉ số breakdown
    match_item = data[0]
    assert "match_score" in match_item
    breakdown = match_item["breakdown"]
    assert "skill_score" in breakdown
    assert "distance_score" in breakdown
    assert "time_score" in breakdown
    assert "reliability_score" in breakdown
    assert "style_score" in breakdown

def test_zero_candidates(sample_payload):
    sample_payload["candidates"] = []
    response = client.post("/api/v1/match", json=sample_payload)
    assert response.status_code == 200
    assert response.json() == []

def test_invalid_host_skills(sample_payload):
    sample_payload["host"]["skills"] = [4.0]
    response = client.post("/api/v1/match", json=sample_payload)
    assert response.status_code == 400