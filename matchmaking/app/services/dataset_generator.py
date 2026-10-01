import csv
import json
from typing import Any, Dict, List


def generate_sample_players() -> List[Dict[str, Any]]:
  """Tạo danh sách Candidate mẫu theo chuẩn Pydantic PlayerProfileInput."""
  return [
      # 1. Ideal Match (Cầu Rồng)
      {
          "user_id": "player_001_ideal",
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
          "location": {"latitude": 16.0611, "longitude": 108.2272},
          "available_time_slots": ["2026-10-01T18:00:00"],
          "playing_style": ["Attack", "Balanced"],
          "reliability_score": 5.0,
      },
      # 2. Distance Case (Hòa Khánh - Khớp skill/giờ nhưng xa ~12km)
      {
          "user_id": "player_002_far",
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
          "location": {"latitude": 16.0752, "longitude": 108.1531},
          "available_time_slots": ["2026-10-01T18:00:00"],
          "playing_style": ["Attack"],
          "reliability_score": 4.5,
      },
      # 3. Skill Mismatch (Trình độ quá cao - Bị Filter loại)
      {
          "user_id": "player_003_pro",
          "skill": {
              "smash": 5.0,
              "defense": 5.0,
              "net_play": 5.0,
              "stamina": 5.0,
              "footwork": 5.0,
              "serve": 5.0,
              "preferred_min": 4,
              "preferred_max": 5,
          },
          "location": {"latitude": 16.0620, "longitude": 108.2250},
          "available_time_slots": ["2026-10-01T18:00:00"],
          "playing_style": ["Defense"],
          "reliability_score": 5.0,
      },
      # 4. Time Mismatch (Lệch khung giờ rảnh - Bị Filter loại)
      {
          "user_id": "player_004_wrong_time",
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
          "location": {"latitude": 16.0590, "longitude": 108.2280},
          "available_time_slots": ["2026-10-01T08:00:00"],
          "playing_style": ["Balanced"],
          "reliability_score": 4.0,
      },
      # 5. Low Reliability (Uy tín thấp)
      {
          "user_id": "player_005_low_reliability",
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
          "location": {"latitude": 16.0600, "longitude": 108.2260},
          "available_time_slots": ["2026-10-01T18:00:00"],
          "playing_style": ["Attack"],
          "reliability_score": 1.5,
      },
  ]


def export_dataset_to_json(filepath: str = "app/data/players_dataset.json"):
  data = generate_sample_players()
  with open(filepath, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
  return filepath


def export_dataset_to_csv(filepath: str = "app/data/players_dataset.csv"):
  data = generate_sample_players()
  if not data:
    return None

  flat_data = []
  for p in data:
    row = {
        "user_id": p["user_id"],
        "avg_skill": sum(
            [
                p["skill"]["smash"],
                p["skill"]["defense"],
                p["skill"]["net_play"],
                p["skill"]["stamina"],
                p["skill"]["footwork"],
                p["skill"]["serve"],
            ]
        )
        / 6.0,
        "latitude": p["location"]["latitude"],
        "longitude": p["location"]["longitude"],
        "available_time_slots": ";".join(p["available_time_slots"]),
        "playing_style": ";".join(p["playing_style"]),
        "reliability_score": p["reliability_score"],
    }
    flat_data.append(row)

  keys = flat_data[0].keys()
  with open(filepath, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=keys)
    writer.writeheader()
    writer.writerows(flat_data)
  return filepath