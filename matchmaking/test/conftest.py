import pytest
from app.schemas import PlayerProfileInput, Location
from app.services.dataset_generator import generate_sample_players


@pytest.fixture
def target_user_input() -> PlayerProfileInput:
    """User mẫu đang tìm trận"""
    return PlayerProfileInput(
        user_id="target_user_da_nang",
        skill={
            "smash": 3.0,
            "defense": 3.0,
            "net_play": 3.0,
            "stamina": 3.0,
            "footwork": 3.0,
            "serve": 3.0,
            "preferred_min": 2,
            "preferred_max": 4,
        },
        location=Location(latitude=16.0611, longitude=108.2272),
        available_time_slots=["2026-10-01T18:00:00"],
        playing_style=["Attack", "Balanced"],
        reliability_score=5.0,
    )


@pytest.fixture
def candidate_players_input() -> list[PlayerProfileInput]:
    """Danh sách các ứng viên chuẩn hóa Pydantic"""
    raw_data = generate_sample_players()
    return [PlayerProfileInput(**item) for item in raw_data]