from app.services.distance import (
    calculate_haversine_distance,
    calculate_player_to_player_distance,
)


def test_haversine_distance_same_point():
    # Cùng 1 điểm -> Khoảng cách = 0 km
    dist = calculate_haversine_distance(16.0678, 108.2208, 16.0678, 108.2208)
    assert dist == 0.0


def test_player_distance_da_nang():
    # Tọa độ Cầu Rồng Đà Nẵng
    p1 = {"latitude": 16.0611, "longitude": 108.2272}
    # Tọa độ Sân bay Đà Nẵng
    p2 = {"latitude": 16.0538, "longitude": 108.1993}

    dist = calculate_player_to_player_distance(p1, p2)
    # Khoảng cách thực tế ~3 km
    assert dist is not None
    assert 2.5 <= dist <= 3.5