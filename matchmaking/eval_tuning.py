"""Script đánh giá & Tuning trọng số Matchmaking (Sprint 8)"""

import random
import pandas as pd
from app.schemas import (
    Location,
    PlayerProfileInput,
    SkillPreference,
)
from app.services.matcher import MatchmakingEngine


def generate_mock_candidates(count=100):
  """Hàm sinh 100 ứng viên thử nghiệm tại Đà Nẵng"""
  candidates = []
  for i in range(count):
    candidates.append(
        PlayerProfileInput(
            user_id=f"cand_eval_{i+1}",
            skill=SkillPreference(
                smash=round(random.uniform(1.0, 5.0), 1),
                defense=round(random.uniform(1.0, 5.0), 1),
                net_play=round(random.uniform(1.0, 5.0), 1),
                stamina=round(random.uniform(1.0, 5.0), 1),
                footwork=round(random.uniform(1.0, 5.0), 1),
                serve=round(random.uniform(1.0, 5.0), 1),
                preferred_min=1,
                preferred_max=5,
            ),
            location=Location(
                latitude=16.0611 + random.uniform(-0.05, 0.05),
                longitude=108.2272 + random.uniform(-0.05, 0.05),
            ),
            available_time_slots=[
                "2026-10-29T18:00:00Z",
                "2026-10-30T19:00:00Z",
            ],
            playing_style=random.sample(
                ["Attack", "Defense", "Balanced"], random.randint(1, 2)
            ),
            reliability_score=round(random.uniform(3.0, 5.0), 1),
        )
    )
  return candidates


def evaluate_weight_profiles():
  print("=" * 60)
  print("🚀 SPRINT 8: MATCHMAKING EVALUATION & WEIGHT TUNING")
  print("=" * 60)

  # 1. Khởi tạo dữ liệu
  candidates = generate_mock_candidates(count=100)

  target_user = PlayerProfileInput(
      user_id="eval_user_main",
      skill=SkillPreference(
          smash=3.5,
          defense=3.0,
          net_play=3.0,
          stamina=4.0,
          footwork=3.5,
          serve=3.0,
          preferred_min=2,
          preferred_max=5,
      ),
      location=Location(latitude=16.0611, longitude=108.2272),
      available_time_slots=[
          "2026-10-29T18:00:00Z",
          "2026-10-30T19:00:00Z",
      ],
      playing_style=["Attack", "Balanced"],
      reliability_score=4.8,
  )

  # 2. Chạy Matchmaking Pipeline
  results = MatchmakingEngine.run_pipeline(
      target_user, candidates=candidates, limit=20
  )

  print(f"\n📊 Tổng số candidates đầu vào: {len(candidates)}")
  print(f"✅ Số candidates vượt qua Hard Filtering & được xếp hạng: {len(results)}")

  if not results:
    print("❌ Không có candidate nào hợp lệ!")
    return

  # 3. Phân tích thống kê Pandas
  data = []
  for r in results:
    data.append({
        "user_id": r.user_id,
        "total_score": r.match_score,
        "skill": r.breakdown.skill_score,
        "distance": r.breakdown.distance_score,
        "time": r.breakdown.time_score,
        "style": r.breakdown.style_score,
        "reliability": r.breakdown.reliability_score,
    })

  df = pd.DataFrame(data)

  print("\n--- 📈 Thống kê phân bố điểm số Top-20 Candidates ---")
  print(df[["total_score", "skill", "distance", "time", "reliability"]].describe())

  print("\n--- 🏆 Top-5 Candidates Phù Hợp Nhất ---")
  print(df.head(5).to_string(index=False))

  # 4. Ma trận tương quan
  corr = df[
      ["total_score", "skill", "distance", "time", "style", "reliability"]
  ].corr()
  print("\n--- 🔗 Ma trận tương quan đóng góp điểm số ---")
  print(corr["total_score"].sort_values(ascending=False))


if __name__ == "__main__":
  evaluate_weight_profiles()