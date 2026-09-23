from app.schemas import Location
from app.services.distance import (
    calculate_haversine_distance,
    calculate_player_to_player_distance,
    calculate_player_to_court_distance,
)


def test_haversine_distance_same_point():
    # Cùng 1 điểm -> Khoảng cách = 0 km
    dist = calculate_haversine_distance(16.0678, 108.2208, 16.0678, 108.2208)
    assert dist == 0.0


def test_player_distance_da_nang_dict():
    # Tọa độ Cầu Rồng Đà Nẵng
    p1 = {"latitude": 16.0611, "longitude": 108.2272}
    # Tọa độ Sân bay Đà Nẵng
    p2 = {"latitude": 16.0538, "longitude": 108.1993}

    dist = calculate_player_to_player_distance(p1, p2)
    # Khoảng cách thực tế ~3 km
    assert dist is not None
    assert 2.5 <= dist <= 3.5


def test_player_distance_with_location_models():
    # Sử dụng Location Pydantic Model
    loc1 = Location(latitude=16.0611, longitude=108.2272)
    loc2 = Location(latitude=16.0538, longitude=108.1993)

    dist = calculate_player_to_player_distance(loc1, loc2)
    assert dist is not None
    assert 2.5 <= dist <= 3.5


def test_player_to_court_distance():
    player_loc = Location(latitude=16.0611, longitude=108.2272)
    court_loc = Location(latitude=16.0700, longitude=108.2200)

    dist = calculate_player_to_court_distance(player_loc, court_loc)
    assert dist is not None
    assert dist > 0.0


def test_distance_invalid_coordinates():
    # Trường hợp toạ độ thiếu / None
    invalid = {"latitude": None, "longitude": 108.0}
    valid = {"latitude": 16.0, "longitude": 108.0}
    assert calculate_player_to_player_distance(invalid, valid) is None
    assert calculate_player_to_player_distance("not_a_loc", valid) is None