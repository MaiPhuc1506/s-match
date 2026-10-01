import math
from typing import Optional, Union
from app.schemas import Location


def calculate_haversine_distance(
    lat1: float, lon1: float, lat2: float, lon2: float
) -> float:
    """
    Tính khoảng cách giữa 2 tọa độ địa lý (vĩ độ, kinh độ) theo công thức Haversine.
    :return: Khoảng cách tính bằng Kilomét (km), làm tròn 2 chữ số thập phân.
    """
    # Bán kính Trái Đất (km)
    R = 6371.0

    # Chuyển đổi độ sang Radian
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    # Công thức Haversine
    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    distance = R * c
    return round(distance, 2)


def calculate_player_to_player_distance(
    player1_location: Union[Location, dict],
    player2_location: Union[Location, dict],
) -> Optional[float]:
    """
    Tính khoảng cách giữa 2 Người chơi (Player - Player).
    Location có thể là Location model hoặc dict: {"latitude": float, "longitude": float}
    """
    try:
        if isinstance(player1_location, Location):
            lat1, lon1 = player1_location.latitude, player1_location.longitude
        elif isinstance(player1_location, dict):
            lat1 = player1_location.get("latitude")
            lon1 = player1_location.get("longitude")
        else:
            return None

        if isinstance(player2_location, Location):
            lat2, lon2 = player2_location.latitude, player2_location.longitude
        elif isinstance(player2_location, dict):
            lat2 = player2_location.get("latitude")
            lon2 = player2_location.get("longitude")
        else:
            return None

        if None in (lat1, lon1, lat2, lon2):
            return None

        return calculate_haversine_distance(float(lat1), float(lon1), float(lat2), float(lon2))
    except Exception:
        return None


def calculate_player_to_court_distance(
    player_location: Union[Location, dict],
    court_location: Union[Location, dict],
) -> Optional[float]:
    """
    Tính khoảng cách từ Người chơi tới Sân cầu lông (Player - Court).
    Location có thể là Location model hoặc dict: {"latitude": float, "longitude": float}
    """
    return calculate_player_to_player_distance(player_location, court_location)