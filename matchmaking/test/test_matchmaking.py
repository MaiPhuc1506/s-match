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
    assert isinstance(data["distance_km"], float)

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
            "skills": [4.0]  # Thừa/thiếu chỉ số (khác 6 phần tử)
        },
        "candidates": []
    }
    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 400
    assert response.json()["detail"] == "Error: Host skill profile is incomplete. Exactly 6 performance metrics are required."

def test_successful_matchmaking_ranking():
    payload = {
        "host": {
            "user_id": "host_01",
            "lat": 16.0544,
            "lon": 108.2022,
            "skills": [4.0, 4.0, 4.0, 4.0, 4.0, 4.0]
        },
        "candidates": [
            {
                "user_id": "cand_near",
                "lat": 16.0550,
                "lon": 108.2030,
                "skills": [4.0, 4.0, 4.0, 4.0, 4.0, 4.0]
            },
            {
                "user_id": "cand_far",
                "lat": 16.1500,
                "lon": 108.3000,
                "skills": [2.0, 2.0, 2.0, 2.0, 2.0, 2.0]
            }
        ]
    }
    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 200
    results = response.json()
    assert len(results) > 0
    # Đảm bảo ứng viên ở gần có match_score cao hơn ứng viên ở xa
    assert results[0]["user_id"] == "cand_near"


def test_equal_score_tie_breaker_ranks_closer_candidate_first():
    # Với max_distance_km rất lớn để distance_score sau làm tròn bằng nhau,
    # hoặc điều chỉnh skill để match_score sau round(2) bằng nhau nhưng distance_km khác nhau:
    payload = {
        "current_user": {
            "user_id": "host_01",
            "location": {"latitude": 16.0544, "longitude": 108.2022},
            "max_distance_km": 100000.0,
            "skill": {
                "smash": 4.0,
                "defense": 4.0,
                "net_play": 4.0,
                "stamina": 4.0,
                "footwork": 4.0,
                "serve": 4.0,
            },
        },
        "candidates": [
            {
                "user_id": "cand_slightly_farther",
                "location": {"latitude": 16.0555, "longitude": 108.2035},
                "max_distance_km": 100000.0,
                "skill": {
                    "smash": 4.0,
                    "defense": 4.0,
                    "net_play": 4.0,
                    "stamina": 4.0,
                    "footwork": 4.0,
                    "serve": 4.0,
                },
            },
            {
                "user_id": "cand_closer",
                "location": {"latitude": 16.0545, "longitude": 108.2023},
                "max_distance_km": 100000.0,
                "skill": {
                    "smash": 4.0,
                    "defense": 4.0,
                    "net_play": 4.0,
                    "stamina": 4.0,
                    "footwork": 4.0,
                    "serve": 4.0,
                },
            },
        ],
    }
    response = client.post("/api/v1/match", json=payload)
    assert response.status_code == 200
    body = response.json()
    assert body["total_candidates_processed"] == 2
    matched = body["matched_users"]
    assert len(matched) == 2
    assert matched[0]["match_score"] == matched[1]["match_score"]
    assert matched[0]["distance_km"] < matched[1]["distance_km"]
    assert matched[0]["user_id"] == "cand_closer"


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
    assert set(item["breakdown"].keys()) == {"distance_score", "skill_score"}
    assert all(isinstance(v, float) for v in item["breakdown"].values())
