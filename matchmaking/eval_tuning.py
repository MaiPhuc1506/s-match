import time
import numpy as np
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def benchmark_matchmaking():
    host = {
        "user_id": "host_danang",
        "lat": 16.0544,
        "lon": 108.2022,
        "skills": [3.5, 4.0, 3.0, 4.0, 3.5, 4.0],
        "reliability_score": 4.5,
        "playing_style": ["Balanced"],
        "available_hours": [17, 18, 19]
    }
    
    candidates = []
    np.random.seed(42)
    styles = ["Aggressive", "Defensive", "Balanced"]
    for i in range(30):
        candidates.append({
            "user_id": f"player_dn_{i+1:02d}",
            "lat": 16.0544 + float(np.random.uniform(-0.1, 0.1)),
            "lon": 108.2022 + float(np.random.uniform(-0.1, 0.1)),
            "skills": [float(x) for x in np.random.uniform(1.0, 5.0, 6)],
            "reliability_score": round(float(np.random.uniform(3.0, 5.0)), 1),
            "playing_style": [str(np.random.choice(styles))],
            "available_hours": [17, 18, 19]
        })
    
    payload = {
        "host": host,
        "candidates": candidates,
        "limit": 10
    }

    start_time = time.time()
    response = client.post("/api/v1/match", json=payload)
    elapsed_ms = (time.time() - start_time) * 1000
    
    assert response.status_code == 200
    results = response.json()
    
    print("\n--- BENCHMARK RESULTS ---")
    print(f"Processed Candidates: {len(candidates)}")
    print(f"Top-K Matches Returned: {len(results)}")
    print(f"Execution Latency: {elapsed_ms:.2f} ms")
    assert elapsed_ms < 800.0, "FAILED: Latency exceeded 800ms limit!"
    print("SUCCESS: Latency within SLA performance limits (< 800ms).\n")

if __name__ == "__main__":
    benchmark_matchmaking()