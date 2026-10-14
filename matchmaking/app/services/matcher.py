import math
from typing import List, Optional
from app.schemas import (
    PlayerProfileInput,
    MatchedUserResult,
    MatchmakingResponse,
    BreakdownScores,
)


def calculate_haversine_distance(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
  """Tính khoảng cách GPS giữa 2 điểm theo công thức Haversine (đơn vị: km)"""
  R = 6371.0
  dlat = math.radians(lat2 - lat1)
  dlon = math.radians(lon2 - lon1)
  a = (
      math.sin(dlat / 2) ** 2
      + math.cos(math.radians(lat1))
      * math.cos(math.radians(lat2))
      * math.sin(dlon / 2) ** 2
  )
  c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
  return R * c


class MatchmakingEngine:

  MAX_DISTANCE_KM: float = 20.0  # Ngưỡng khoảng cách tối đa (km)

  @staticmethod
  def is_eligible(
      user: PlayerProfileInput, candidate: PlayerProfileInput
  ) -> bool:
    """Bộ lọc cứng (Hard Filtering): Loại bỏ candidate không thỏa điều kiện cơ bản"""
    # 1. Kiểm tra khoảng cách GPS
    dist_km = calculate_haversine_distance(
        user.location.latitude,
        user.location.longitude,
        candidate.location.latitude,
        candidate.location.longitude,
    )
    if dist_km > MatchmakingEngine.MAX_DISTANCE_KM:
      return False

    # 2. Kiểm tra trùng thời gian rảnh
    user_slots = set(user.available_time_slots)
    candidate_slots = set(candidate.available_time_slots)
    if not user_slots.intersection(candidate_slots):
      return False

    # 3. Kiểm tra dải trình độ phù hợp (preferred_min <= cand_skill <= preferred_max)
    cand_avg_skill = (
        candidate.skill.smash
        + candidate.skill.defense
        + candidate.skill.net_play
        + candidate.skill.stamina
        + candidate.skill.footwork
        + candidate.skill.serve
    ) / 6.0

    if not (
        user.skill.preferred_min <= cand_avg_skill <= user.skill.preferred_max
    ):
      return False

    return True

  @staticmethod
  def calculate_score(
      user: PlayerProfileInput, candidate: PlayerProfileInput
  ) -> MatchedUserResult:
    """Tính toán điểm phù hợp chi tiết (Compatibility Scoring)"""
    # 1. Skill Score (Max 30đ)
    user_avg = (
        user.skill.smash
        + user.skill.defense
        + user.skill.net_play
        + user.skill.stamina
        + user.skill.footwork
        + user.skill.serve
    ) / 6.0

    cand_avg = (
        candidate.skill.smash
        + candidate.skill.defense
        + candidate.skill.net_play
        + candidate.skill.stamina
        + candidate.skill.footwork
        + candidate.skill.serve
    ) / 6.0

    skill_diff = abs(user_avg - cand_avg)
    skill_score = max(0.0, 30.0 - (skill_diff * 10.0))

    # 2. Distance Score (Max 25đ)
    dist_km = calculate_haversine_distance(
        user.location.latitude,
        user.location.longitude,
        candidate.location.latitude,
        candidate.location.longitude,
    )
    distance_score = max(0.0, 25.0 - (dist_km * 1.0))

    # 3. Time Score (Max 20đ)
    user_slots = set(user.available_time_slots)
    cand_slots = set(candidate.available_time_slots)
    common_slots = len(user_slots.intersection(cand_slots))
    time_score = min(20.0, common_slots * 10.0)

    # 4. Style Score (Max 10đ)
    user_styles = set(user.playing_style)
    cand_styles = set(candidate.playing_style)
    style_match = (
        len(user_styles.intersection(cand_styles)) / len(user_styles)
        if user_styles
        else 0.5
    )
    style_score = style_match * 10.0

    # 5. Reliability Score (Max 15đ)
    reliability_score = (candidate.reliability_score / 5.0) * 15.0

    # Tổng điểm Match Score (Max 100đ)
    total_score = round(
        skill_score
        + distance_score
        + time_score
        + style_score
        + reliability_score,
        2,
    )

    breakdown = BreakdownScores(
        skill_score=round(skill_score, 2),
        time_score=round(time_score, 2),
        distance_score=round(distance_score, 2),
        style_score=round(style_score, 2),
        reliability_score=round(reliability_score, 2),
    )

    return MatchedUserResult(
        user_id=candidate.user_id,
        match_score=total_score,
        breakdown=breakdown,
    )

  @classmethod
  def run_pipeline(
      cls,
      current_user: PlayerProfileInput = None,
      user: PlayerProfileInput = None,
      candidates: List[PlayerProfileInput] = None,
      limit: int = 10,
      return_response_model: bool = False,
  ):
    """Quy trình Lọc ứng viên & Xếp hạng điểm (Pipeline)"""
    target_user = current_user or user
    matched_results: List[MatchedUserResult] = []

    for candidate in candidates or []:
      if candidate.user_id == target_user.user_id:
        continue

      if not cls.is_eligible(target_user, candidate):
        continue

      result = cls.calculate_score(target_user, candidate)
      matched_results.append(result)

    matched_results.sort(key=lambda x: x.match_score, reverse=True)
    sliced_results = matched_results[:limit]

    if return_response_model:
      return MatchmakingResponse(
          matched_users=sliced_results,
          total_candidates_processed=len(candidates or []),
      )

    return sliced_results