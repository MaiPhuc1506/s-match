from app.schemas import PlayerProfileInput, SkillPreference, Location
from app.services.matcher import MatchmakingEngine


def create_mock_player(
    user_id: str,
    avg_skill: float,
    lat: float,
    lon: float,
    time_slots: list,
    pref_min: int = 1,
    pref_max: int = 5,
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
          preferred_min=pref_min,
          preferred_max=pref_max,
      ),
      location=Location(latitude=lat, longitude=lon),
      available_time_slots=time_slots,
      playing_style=["Attack"],
      reliability_score=5.0,
  )


def test_candidate_filtering_and_scoring():
  # User A tại Đà Nẵng (yêu cầu trình độ từ 2 đến 4)
  user_a = create_mock_player(
      "user_A",
      3.0,
      16.0611,
      108.2272,
      ["2026-10-07T18:00:00"],
      pref_min=2,
      pref_max=4,
  )

  # Candidate 1: Phù hợp (Gần, Trùng giờ, Trình độ 3.5)
  cand_valid = create_mock_player(
      "cand_valid", 3.5, 16.0650, 108.2200, ["2026-10-07T18:00:00"]
  )

  # Candidate 2: Quá xa (> 20km - Hồ Chí Minh)
  cand_far = create_mock_player(
      "cand_far", 3.0, 10.7769, 106.7009, ["2026-10-07T18:00:00"]
  )

  # Candidate 3: Không trùng giờ rảnh
  cand_no_time = create_mock_player(
      "cand_no_time", 3.0, 16.0611, 108.2272, ["2026-10-08T08:00:00"]
  )

  # Candidate 4: Trình độ không nằm trong khoảng preferred (Skill = 1.0 < min 2)
  cand_out_of_skill = create_mock_player(
      "cand_out_skill", 1.0, 16.0611, 108.2272, ["2026-10-07T18:00:00"]
  )

  candidates = [cand_valid, cand_far, cand_no_time, cand_out_of_skill]

  # Bật return_response_model=True để nhận MatchmakingResponse
  response = MatchmakingEngine.run_pipeline(
      user_a, candidates=candidates, return_response_model=True
  )

  # Kiểm tra kết quả
  assert len(response.matched_users) == 1
  assert response.matched_users[0].user_id == "cand_valid"
  assert response.matched_users[0].match_score > 0