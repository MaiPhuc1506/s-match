from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_distance_calculation():
    payload = {
        "lat1": 16.0544,
        "lon1": 108.2022,
        "lat2": 16.0600,
        "lon2": 108.2100
    }
    response = client.post("/api/v1/distance", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "distance_km" in data
    assert data["unit"] == "km"

def test_no_candidates_returns_empty():
    payload = {
        "host": {
            "user_id": "host_01",
            "lat": 16.0544,
            "lon": 108.2022,
            "skills": [4.0, 3.5, 4.0, 3.0, 4.5, 3.5]
        },
        "candidates": []
    }
    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 200
    assert response.json() == []

def test_missing_host_skills_raises_bad_request():
    payload = {
        "host": {
            "user_id": "host_01",
            "lat": 16.0544,
            "lon": 108.2022,
            "skills": [4.0]
        },
        "candidates": []
    }
    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 400

def test_nestjs_contract_shape_and_empty_candidates():
    empty_payload = {
        "current_user": {
            "user_id": "8",
            "skill": {
                "smash": 3,
                "defense": 3,
                "net_play": 3,
                "stamina": 3,
                "footwork": 3,
                "serve": 3,
                "preferred_min": 2,
                "preferred_max": 4,
            },
            "available_time_slots": ["2026-10-20T18:00:00Z"],
            "location": {"latitude": 16.0, "longitude": 108.0},
            "max_distance_km": 10,
            "playing_style": ["aggressive"],
            "reliability_score": 5,
        },
        "candidates": [],
    }
    empty_res = client.post("/api/v1/match", json=empty_payload)
    assert empty_res.status_code == 200
    assert empty_res.json() == {"total_candidates_processed": 0, "matched_users": []}

    full_payload = {
        "current_user": empty_payload["current_user"],
        "candidates": [
            {
                "user_id": "7",
                "skill": {
                    "smash": 3,
                    "defense": 3,
                    "net_play": 3,
                    "stamina": 3,
                    "footwork": 3,
                    "serve": 3,
                    "preferred_min": 2,
                    "preferred_max": 4,
                },
                "available_time_slots": ["2026-10-20T18:00:00Z"],
                "location": {"latitude": 16.005, "longitude": 108.005},
                "max_distance_km": 10,
                "playing_style": ["aggressive"],
                "reliability_score": 5,
            }
        ],
    }
    res = client.post("/api/v1/match", json=full_payload)
    assert res.status_code == 200
    data = res.json()
    assert data["total_candidates_processed"] == 1
    assert len(data["matched_users"]) == 1
    item = data["matched_users"][0]
    assert item["user_id"] == "7"
    assert isinstance(item["match_score"], float)
    assert isinstance(item["distance_km"], float)
    
    expected_breakdown_keys = {
        "skill_score",
        "distance_score",
        "time_score",
        "reliability_score",
        "style_score"
    }
    assert set(item["breakdown"].keys()) == expected_breakdown_keys