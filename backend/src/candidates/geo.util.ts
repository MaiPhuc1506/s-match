const EARTH_RADIUS_KM = 6371;
const KM_PER_DEGREE_LAT = 111.32;

function toRadians(deg: number): number {
  return (deg * Math.PI) / 180;
}

/** Khoảng cách Haversine (km) — cùng công thức với matchmaking/app/services/distance.py */
export function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) * Math.sin(dLon / 2) ** 2;
  return EARTH_RADIUS_KM * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Hình chữ nhật bao quanh vòng tròn bán kính `radiusKm` — dùng để lọc thô bằng
 * index (latitude, longitude) trong DB trước khi tính Haversine chính xác.
 */
export function boundingBox(lat: number, lon: number, radiusKm: number) {
  const latDelta = radiusKm / KM_PER_DEGREE_LAT;
  const cosLat = Math.max(Math.cos(toRadians(lat)), 0.01);
  const lonDelta = radiusKm / (KM_PER_DEGREE_LAT * cosLat);
  return {
    minLat: lat - latDelta,
    maxLat: lat + latDelta,
    minLon: lon - lonDelta,
    maxLon: lon + lonDelta,
  };
}
