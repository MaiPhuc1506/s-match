import math
from typing import List
from app.config import settings
from app.schemas import (
    PlayerProfileInput,
    MatchedUserResult,
    MatchmakingResponse,
    BreakdownScores,
)


def calculate_haversine_distance(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
  """Tính khoảng cách GPS giữa 2 điểm (km)"""
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

  @staticmethod
  def is_eligible(
      user: PlayerProfileInput, candidate: PlayerProfileInput
  ) -> bool:
    """Bộ lọc cứng (Hard Filtering)"""
    # 1. Khoảng cách GPS <= MAX_DISTANCE_KM
    dist_km = calculate_haversine_distance(
        user.location.latitude,
        user.location.longitude,
        candidate.location.latitude,
        candidate.location.longitude,
    )
    if dist_km > settings.MAX_DISTANCE_KM:
      return False

    # 2. Khung giờ rảnh
    if not set(user.available_time_slots).intersection(
        set(candidate.available_time_slots)
    ):
      return False

    # 3. Dải trình độ
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
    """Tính điểm tương thích chi tiết (Scoring) dựa trên cấu hình Settings"""
    # 1. Skill Score
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
    skill_score = max(0.0, settings.WEIGHT_SKILL - (skill_diff * 10.0))

    # 2. Distance Score
    dist_km = calculate_haversine_distance(
        user.location.latitude,
        user.location.longitude,
        candidate.location.latitude,
        candidate.location.longitude,
    )
    distance_score = max(0.0, settings.WEIGHT_DISTANCE - (dist_km * 1.0))

    # 3. Time Score
    common_slots = len(
        set(user.available_time_slots).intersection(
            set(candidate.available_time_slots)
        )
    )
    time_score = min(settings.WEIGHT_TIME, common_slots * 10.0)

    # 4. Style Score
    user_styles = set(user.playing_style)
    cand_styles = set(candidate.playing_style)
    style_match = (
        len(user_styles.intersection(cand_styles)) / len(user_styles)
        if user_styles
        else 0.5
    )
    style_score = style_match * settings.WEIGHT_STYLE

    # 5. Reliability Score
    reliability_score = (
        candidate.reliability_score / 5.0
    ) * settings.WEIGHT_RELIABILITY

    # Tổng điểm Match Score (Max 100)
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
    """Pipeline: Filter -> Score -> Rank -> Top-K"""
    target_user = current_user or user
    matched_results: List[MatchedUserResult] = []

    # 1. Filter & Score
    for candidate in candidates or []:
      if candidate.user_id == target_user.user_id:
        continue

      if not cls.is_eligible(target_user, candidate):
        continue

      result = cls.calculate_score(target_user, candidate)
      matched_results.append(result)

    # 2. Ranking (Sắp xếp giảm dần theo match_score)
    matched_results.sort(key=lambda x: x.match_score, reverse=True)

    # 3. Top-K Extraction
    top_k_results = matched_results[:limit]

    if return_response_model:
      return MatchmakingResponse(
          matched_users=top_k_results,
          total_candidates_processed=len(candidates or []),
      )

    return top_k_results