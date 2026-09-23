import math
from typing import Optional


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
    player1_location: dict, player2_location: dict
) -> Optional[float]:
    """
    Tính khoảng cách giữa 2 Người chơi (Player - Player).
    Location dict format: {"latitude": float, "longitude": float}
    """
    try:
        lat1 = player1_location.get("latitude")
        lon1 = player1_location.get("longitude")
        lat2 = player2_location.get("latitude")
        lon2 = player2_location.get("longitude")

        if None in (lat1, lon1, lat2, lon2):
            return None

        return calculate_haversine_distance(lat1, lon1, lat2, lon2)
    except Exception:
        return None


def calculate_player_to_court_distance(
    player_location: dict, court_location: dict
) -> Optional[float]:
    """
    Tính khoảng cách từ Người chơi tới Sân cầu lông (Player - Court).
    Location dict format: {"latitude": float, "longitude": float}
    """
    return calculate_player_to_player_distance(player_location, court_location)

# --- Đoạn code chạy thử bằng cách nhập thủ công từ bàn phím ---
if __name__ == "__main__":
    print("=== CHƯƠNG TRÌNH TÍNH KHOẢNG CÁCH S-MATCH ===")
    try:
        print("\n--- Nhập vị trí 1 (Người chơi 1 / Vị trí hiện tại) ---")
        lat1 = float(input("Nhập Vĩ độ (Latitude 1, ví dụ 16.0611): "))
        lon1 = float(input("Nhập Kinh độ (Longitude 1, ví dụ 108.2272): "))

        print("\n--- Nhập vị trí 2 (Người chơi 2 / Sân cầu lông) ---")
        lat2 = float(input("Nhập Vĩ độ (Latitude 2, ví dụ 16.0538): "))
        lon2 = float(input("Nhập Kinh độ (Longitude 2, ví dụ 108.1993): "))

        p1 = {"latitude": lat1, "longitude": lon1}
        p2 = {"latitude": lat2, "longitude": lon2}

        dist = calculate_player_to_player_distance(p1, p2)

        print("\n-------------------------------------------")
        print(f"📍 Khoảng cách giữa 2 điểm là: {dist} km")
        print("-------------------------------------------")

    except ValueError:
        print("\n❌ Lỗi: Vui lòng nhập số thực hợp lệ cho tọa độ!")