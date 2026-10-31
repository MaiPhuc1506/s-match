import random
from app.schemas import Location, PlayerProfileInput, SkillPreference
from app.services.matcher import MatchmakingEngine


def generate_mock_candidates(count=100):
  """Hàm hỗ trợ sinh 100 candidates thử nghiệm cho test suite"""
  candidates = []
  for i in range(count):
    candidates.append(
        PlayerProfileInput(
            user_id=f"cand_test_{i+1}",
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
            available_time_slots=["2026-10-29T18:00:00Z"],
            playing_style=["Attack"],
            reliability_score=round(random.uniform(3.0, 5.0), 1),
        )
    )
  return candidates


def test_matchmaking_evaluation_large_dataset():
  """Kiểm thử hiệu năng & tính chính xác của Top-K trên tập dữ liệu lớn"""
  candidates = generate_mock_candidates(count=100)

  target_user = PlayerProfileInput(
      user_id="user_test_eval",
      skill=SkillPreference(
          smash=3.0,
          defense=3.0,
          net_play=3.0,
          stamina=3.0,
          footwork=3.0,
          serve=3.0,
          preferred_min=1,
          preferred_max=5,
      ),
      location=Location(latitude=16.0611, longitude=108.2272),
      available_time_slots=["2026-10-29T18:00:00Z"],
      playing_style=["Attack"],
      reliability_score=5.0,
  )

  # Chạy pipeline lấy Top-10
  top_10 = MatchmakingEngine.run_pipeline(
      target_user, candidates=candidates, limit=10
  )

  # 1. Đảm bảo Top-K trả về tối đa 10 kết quả
  assert len(top_10) <= 10

  # 2. Đảm bảo điểm số được sắp xếp giảm dần tuyệt đối
  scores = [m.match_score for m in top_10]
  assert scores == sorted(scores, reverse=True)

  # 3. Đảm bảo mọi tổng điểm match_score hợp lệ (0 <= score <= 100)
  for item in top_10:
    assert 0.0 <= item.match_score <= 100.0
    assert item.breakdown.skill_score >= 0.0
    assert item.breakdown.distance_score >= 0.0
    assert item.breakdown.time_score >= 0.0
    assert item.breakdown.style_score >= 0.0
    assert item.breakdown.reliability_score >= 0.0


def test_weight_tuning_consistency():
  """Kiểm thử tính nhất quán khi vị trí khoảng cách thay đổi"""
  user_main = PlayerProfileInput(
      user_id="user_main",
      skill=SkillPreference(
          smash=3.0,
          defense=3.0,
          net_play=3.0,
          stamina=3.0,
          footwork=3.0,
          serve=3.0,
          preferred_min=1,
          preferred_max=5,
      ),
      location=Location(latitude=16.0611, longitude=108.2272),
      available_time_slots=["2026-10-29T18:00:00Z"],
      playing_style=["Attack"],
      reliability_score=5.0,
  )

  # Candidate A: Trùng vị trí hoàn toàn
  cand_a = PlayerProfileInput(
      user_id="cand_a",
      skill=SkillPreference(
          smash=3.0,
          defense=3.0,
          net_play=3.0,
          stamina=3.0,
          footwork=3.0,
          serve=3.0,
          preferred_min=1,
          preferred_max=5,
      ),
      location=Location(latitude=16.0611, longitude=108.2272),
      available_time_slots=["2026-10-29T18:00:00Z"],
      playing_style=["Attack"],
      reliability_score=5.0,
  )

  # Candidate B: Khoảng cách xa hơn một chút
  cand_b = PlayerProfileInput(
      user_id="cand_b",
      skill=SkillPreference(
          smash=3.0,
          defense=3.0,
          net_play=3.0,
          stamina=3.0,
          footwork=3.0,
          serve=3.0,
          preferred_min=1,
          preferred_max=5,
      ),
      location=Location(latitude=16.0900, longitude=108.2500),
      available_time_slots=["2026-10-29T18:00:00Z"],
      playing_style=["Attack"],
      reliability_score=5.0,
  )

  results = MatchmakingEngine.run_pipeline(
      user_main, candidates=[cand_b, cand_a], limit=10
  )

  # Candidate A (ở gần hơn) bắt buộc phải xếp ở Top 1
  assert results[0].user_id == "cand_a"
  assert results[1].user_id == "cand_b"