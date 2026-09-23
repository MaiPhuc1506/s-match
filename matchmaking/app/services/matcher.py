from typing import List
from app.schemas import PlayerProfileInput, MatchedUserResult, BreakdownScores
from app.services.distance import calculate_player_to_player_distance


class MatchmakingEngine:
    @staticmethod
    def filter_candidates(user: PlayerProfileInput, candidates: List[PlayerProfileInput]) -> List[PlayerProfileInput]:
        """Lọc cứng: Lịch rảnh trùng nhau & Trình độ nằm trong khoảng cho phép"""
        filtered = []
        user_slots = set(user.available_time_slots)

        for c in candidates:
            if c.user_id == user.user_id:
                continue

            # 1. Lọc trùng khung giờ rảnh (nếu cả 2 có set lịch rảnh)
            cand_slots = set(c.available_time_slots)
            has_common_time = True
            if user_slots and cand_slots:
                has_common_time = len(user_slots.intersection(cand_slots)) > 0

            # 2. Lọc chênh lệch trình độ theo preferred min-max
            user_avg_skill = (
                user.skill.smash
                + user.skill.defense
                + user.skill.net_play
                + user.skill.stamina
                + user.skill.footwork
                + user.skill.serve
            ) / 6.0
            cand_avg_skill = (
                c.skill.smash
                + c.skill.defense
                + c.skill.net_play
                + c.skill.stamina
                + c.skill.footwork
                + c.skill.serve
            ) / 6.0

            skill_match = (
                user.skill.preferred_min <= cand_avg_skill <= user.skill.preferred_max
            ) and (
                c.skill.preferred_min <= user_avg_skill <= c.skill.preferred_max
            )

            if has_common_time and skill_match:
                filtered.append(c)

        return filtered

    @staticmethod
    def calculate_score(user: PlayerProfileInput, candidate: PlayerProfileInput) -> MatchedUserResult:
        """Tính điểm tương thích đa tiêu chí (Trình độ, Vị trí/Khoảng cách GPS, Style, Độ uy tín, Thời gian)"""
        # 1. Điểm Tương thích Trình độ (Tối đa 30 điểm)
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
        skill_score = max(0.0, 30.0 - (skill_diff * 6.0))

        # 2. Điểm Vị trí Địa lý (Haversine Distance - Tối đa 25 điểm)
        dist_km = calculate_player_to_player_distance(user.location, candidate.location)
        if dist_km is None:
            dist_km = 999.0
        # Điểm giảm dần theo km: 0km -> 25đ, 25km+ -> 0đ
        distance_score = max(0.0, 25.0 - (dist_km * 1.0))

        # 3. Điểm Thời gian rảnh (Tối đa 15 điểm)
        user_slots = set(user.available_time_slots)
        cand_slots = set(candidate.available_time_slots)
        common_slots = user_slots.intersection(cand_slots)
        time_score = min(15.0, len(common_slots) * 5.0) if (user_slots and cand_slots) else 10.0

        # 4. Điểm Độ uy tín Cộng đồng (reliability_score từ 0 -> 5: Tối đa 15 điểm)
        reliability_score = (candidate.reliability_score / 5.0) * 15.0

        # 5. Điểm Phong cách chơi chung (Tối đa 15 điểm)
        user_style = set(user.playing_style)
        cand_style = set(candidate.playing_style)
        common_style = user_style.intersection(cand_style)
        if common_style and user_style:
            style_score = (len(common_style) / len(user_style)) * 15.0
        else:
            style_score = 5.0

        total_score = round(
            skill_score + distance_score + time_score + reliability_score + style_score,
            2
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
        cls, user: PlayerProfileInput, candidates: List[PlayerProfileInput], limit: int
    ) -> List[MatchedUserResult]:
        valid_candidates = cls.filter_candidates(user, candidates)
        scored_results = [cls.calculate_score(user, cand) for cand in valid_candidates]
        ranked_results = sorted(scored_results, key=lambda x: x.match_score, reverse=True)
        return ranked_results[:limit]