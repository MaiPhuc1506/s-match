from app.schemas import PlayerProfileInput, SkillPreference, Location
from app.services.matcher import MatchmakingEngine


def create_player(
    user_id: str,
    avg_skill: float,
    lat: float,
    lon: float,
    time_slots: list,
    reliability: float = 5.0,
) -> PlayerProfileInput:
  return PlayerProfileInput(
      user_id=user_id,
      skill=SkillPreference(
          smash=avg_skill,
          defense=avg_skill,
          net_play=avg_skill,
          stamina=avg_skill,
          footwork=avg_skill,
          serve=avg_skill,
          preferred_min=1,
          preferred_max=5,
      ),
      location=Location(latitude=lat, longitude=lon),
      available_time_slots=time_slots,
      playing_style=["Attack"],
      reliability_score=reliability,
  )


def test_top_k_ranking_and_scoring():
  # User gốc tại Đà Nẵng
  user_main = create_player(
      "user_main", 3.0, 16.0611, 108.2272, ["2026-10-07T18:00:00"]
  )

  # Tạo 5 candidates hợp lệ nhưng điểm số khác nhau
  cand_1 = create_player(
      "cand_best", 3.0, 16.0611, 108.2272, ["2026-10-07T18:00:00"], 5.0
  )  # Điểm cao nhất
  cand_2 = create_player(
      "cand_mid_1", 3.5, 16.0700, 108.2300, ["2026-10-07T18:00:00"], 4.5
  )
  cand_3 = create_player(
      "cand_mid_2", 4.0, 16.0800, 108.2400, ["2026-10-07T18:00:00"], 4.0
  )
  cand_4 = create_player(
      "cand_low_1", 4.5, 16.0900, 108.2500, ["2026-10-07T18:00:00"], 3.5
  )
  cand_5 = create_player(
      "cand_low_2", 4.8, 16.1000, 108.2600, ["2026-10-07T18:00:00"], 3.0
  )  # Điểm thấp nhất

  candidates = [cand_3, cand_5, cand_1, cand_4, cand_2]  # Thứ tự xáo trộn

  # Yêu cầu lấy Top-3 (limit = 3)
  response = MatchmakingEngine.run_pipeline(
      user_main, candidates=candidates, limit=3, return_response_model=True
  )

  # 1. Kiểm tra giới hạn Top-K (Limit = 3)
  assert len(response.matched_users) == 3

  # 2. Kiểm tra thứ tự Ranking (Điểm giảm dần)
  scores = [m.match_score for m in response.matched_users]
  assert scores == sorted(scores, reverse=True)

  # 3. Candidate điểm cao nhất phải đứng đầu Top-1
  assert response.matched_users[0].user_id == "cand_best"