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