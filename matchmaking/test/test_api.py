from datetime import datetime
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_api_calculate_distance():
    payload = {
        "point_a": {"latitude": 16.0611, "longitude": 108.2272},
        "point_b": {"latitude": 16.0538, "longitude": 108.1993},
    }
    response = client.post("/api/v1/distance", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "distance_km" in data
    assert 2.5 <= data["distance_km"] <= 3.5
    assert data["unit"] == "km"


def test_api_matchmaking_with_distance():
    now = datetime.now().isoformat()
    payload = {
        "current_user": {
            "user_id": "u1",
            "skill": {
                "smash": 3.0,
                "defense": 3.0,
                "net_play": 3.0,
                "stamina": 3.0,
                "footwork": 3.0,
                "serve": 3.0,
                "preferred_min": 2,
                "preferred_max": 4,
            },
            "available_time_slots": [now],
            "location": {"latitude": 16.0611, "longitude": 108.2272},
            "playing_style": ["aggressive"],
            "reliability_score": 5.0,
        },
        "candidates": [
            {
                "user_id": "u2",
                "skill": {
                    "smash": 3.0,
                    "defense": 3.0,
                    "net_play": 3.0,
                    "stamina": 3.0,
                    "footwork": 3.0,
                    "serve": 3.0,
                    "preferred_min": 2,
                    "preferred_max": 4,
                },
                "available_time_slots": [now],
                "location": {"latitude": 16.0620, "longitude": 108.2280},  # rất gần (~0.1km)
                "playing_style": ["aggressive"],
                "reliability_score": 5.0,
            }
        ],
        "limit": 5,
    }

    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["total_candidates_processed"] == 1
    assert len(data["matched_users"]) == 1
    matched = data["matched_users"][0]
    assert matched["user_id"] == "u2"
    assert matched["breakdown"] is not None
    # distance score cao vì gần nhau
    assert matched["breakdown"]["distance_score"] >= 20.0

