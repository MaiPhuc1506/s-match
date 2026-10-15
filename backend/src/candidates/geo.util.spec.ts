import { boundingBox, haversineKm } from './geo.util';

describe('geo.util', () => {
  describe('haversineKm', () => {
    it('returns 0 for identical points', () => {
      expect(haversineKm(16.05, 108.2, 16.05, 108.2)).toBeCloseTo(0, 5);
    });

    it('computes ~111 km for 1 degree of latitude', () => {
      expect(haversineKm(0, 0, 1, 0)).toBeCloseTo(111.19, 1);
    });

    it('is symmetric', () => {
      const ab = haversineKm(16.047, 108.206, 15.88, 108.33);
      const ba = haversineKm(15.88, 108.33, 16.047, 108.206);
      expect(ab).toBeCloseTo(ba, 6);
    });
  });

  describe('boundingBox', () => {
    it('contains every point within the radius', () => {
      const lat = 16.047;
      const lon = 108.206;
      const radius = 10;
      const box = boundingBox(lat, lon, radius);

      // Điểm cách đúng ~10km về phía Bắc và Đông phải nằm trong box
      const north = lat + radius / 111.32;
      const east = lon + radius / (111.32 * Math.cos((lat * Math.PI) / 180));
      expect(north).toBeLessThanOrEqual(box.maxLat + 1e-9);
      expect(east).toBeLessThanOrEqual(box.maxLon + 1e-9);
      expect(box.minLat).toBeLessThan(lat);
      expect(box.minLon).toBeLessThan(lon);
    });
  });
});
