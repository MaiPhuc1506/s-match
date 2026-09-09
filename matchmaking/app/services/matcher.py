import math
from typing import List
from app.schemas import PlayerProfile, MatchResult

class MatchmakingEngine:
    
    @staticmethod
    def filter_candidates(user: PlayerProfile, candidates: List[PlayerProfile]) -> List[PlayerProfile]:
        """Lọc cứng: Lịch rảnh trùng nhau & Trình độ nằm trong khoảng cho phép"""
        filtered = []
        user_slots = set(user.available_time_slots)
        
        for c in candidates:
            if c.user_id == user.user_id:
                continue
                
            # 1. Lọc trùng khung giờ rảnh
            cand_slots = set(c.available_time_slots)
            has_common_time = len(user_slots.intersection(cand_slots)) > 0
            
            # 2. Lọc chênh lệch trình độ quá lớn
            skill_match = (user.preferred_skill_min <= c.skill_level <= user.preferred_skill_max) and \
                          (c.preferred_skill_min <= user.skill_level <= c.preferred_skill_max)
                          
            if has_common_time and skill_match:
                filtered.append(c)
                
        return filtered

    @staticmethod
    def calculate_score(user: PlayerProfile, candidate: PlayerProfile) -> MatchResult:
        """Tính điểm tương thích đa tiêu chí (Trình độ, Vị trí, Style, Độ uy tín)"""
        score = 0.0
        reasons = []

        # 1. Điểm Tương thích Trình độ (Tối đa 30 điểm)
        skill_diff = abs(user.skill_level - candidate.skill_level)
        skill_score = max(0.0, 30.0 - (skill_diff * 10))
        score += skill_score
        if skill_diff == 0:
            reasons.append("Cùng trình độ thi đấu")

        # 2. Điểm Vị trí Địa lý (Tối đa 30 điểm)
        dist = math.sqrt((user.location_x - candidate.location_x)**2 + (user.location_y - candidate.location_y)**2)
        location_score = max(0.0, 30.0 - (dist * 3))
        score += location_score
        if dist < 3.0:
            reasons.append("Sân đấu gần vị trí của bạn")

        # 3. Điểm Độ uy tín Cộng đồng (Post-match feedback - Tối đa 20 điểm)
        # reliability_score từ 0 -> 5 sao
        reliability_score = (candidate.reliability_score / 5.0) * 20.0
        score += reliability_score
        if candidate.reliability_score >= 4.5:
            reasons.append("Người chơi có độ uy tín cao (Ít bùng kèo)")

        # 4. Điểm Phong cách chơi chung (Tối đa 20 điểm)
        user_style = set(user.playing_style)
        cand_style = set(candidate.playing_style)
        common_style = user_style.intersection(cand_style)
        if common_style:
            style_score = (len(common_style) / max(len(user_style), 1)) * 20.0
            score += style_score
            reasons.append("Hợp phong cách thi đấu")

        return MatchResult(
            user_id=candidate.user_id,
            score=round(score, 2),
            reasons=reasons
        )

    @classmethod
    def run_pipeline(cls, user: PlayerProfile, candidates: List[PlayerProfile], limit: int) -> List[MatchResult]:
        valid_candidates = cls.filter_candidates(user, candidates)
        scored_results = [cls.calculate_score(user, cand) for cand in valid_candidates]
        ranked_results = sorted(scored_results, key=lambda x: x.score, reverse=True)
        return ranked_results[:limit]