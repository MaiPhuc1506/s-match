from app.services.matcher import MatchmakingEngine


def test_matcher_pipeline_with_dataset(target_user_input, candidate_players_input):
    # 1. Chạy pipeline ghép trận
    results = MatchmakingEngine.run_pipeline(
        user=target_user_input,
        candidates=candidate_players_input,
        limit=5
    )

    # 2. Kiểm tra Filter: player_003_pro (sai skill) & player_004_wrong_time (sai giờ) phải bị lọc
    returned_ids = [r.user_id for r in results]
    assert "player_003_pro" not in returned_ids
    assert "player_004_wrong_time" not in returned_ids

    # 3. Kiểm tra Ranking: player_001_ideal phải xếp HẠNG NẤT
    assert len(results) > 0
    assert results[0].user_id == "player_001_ideal"

    # 4. Check Breakdown score
    top_match = results[0]
    assert top_match.match_score > 80.0
    assert top_match.breakdown.distance_score == 25.0