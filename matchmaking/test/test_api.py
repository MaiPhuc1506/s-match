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

def test_api_matchmaking_filters_out_far_candidates():
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
            "location": {"latitude": 16.0611, "longitude": 108.2272},  # Đà Nẵng
            "max_distance_km": 10.0,
            "playing_style": ["aggressive"],
            "reliability_score": 5.0,
        },
        "candidates": [
            {
                "user_id": "u_near",
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
                "location": {"latitude": 16.0620, "longitude": 108.2280},  # Gần (~0.1km)
                "max_distance_km": 10.0,
                "playing_style": ["aggressive"],
                "reliability_score": 5.0,
            },
            {
                "user_id": "u_far",
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
                "location": {"latitude": 16.4637, "longitude": 107.5909},  # Huế (~80km, vượt quá 10km)
                "max_distance_km": 10.0,
                "playing_style": ["aggressive"],
                "reliability_score": 5.0,
            },
        ],
        "limit": 5,
    }

    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 200
    data = response.json()

    # Tổng ứng viên quét: 2
    assert data["total_candidates_processed"] == 2
    # Chỉ có 1 người hợp lệ được trả về (u_near), u_far bị loại do ở xa > 10km
    assert len(data["matched_users"]) == 1
    assert data["matched_users"][0]["user_id"] == "u_near"