import { BadRequestException } from '@nestjs/common';
import {
  availableHours,
  bookedHoursInRange,
  enumeratePeriods,
  MAX_RANGE_DAYS,
  periodKey,
  ratio,
  resolveDateRange,
  timeToHours,
  weekdayCounts,
  weeklyOpenHours,
} from './analytics.util';

describe('analytics.util', () => {
  describe('resolveDateRange', () => {
    it('defaults to the last 30 days ending today (Vietnam time)', () => {
      const range = resolveDateRange(undefined, undefined, new Date('2026-11-01T10:00:00.000Z'));

      expect(range.toDate).toBe('2026-11-01');
      expect(range.fromDate).toBe('2026-10-03');
      expect(range.days).toBe(30);
      expect(range.start.toISOString()).toBe('2026-10-02T17:00:00.000Z');
      expect(range.end.toISOString()).toBe('2026-11-01T17:00:00.000Z');
    });

    it('treats late UTC evening as the next calendar day in Vietnam', () => {
      const range = resolveDateRange(undefined, undefined, new Date('2026-10-31T18:00:00.000Z'));
      expect(range.toDate).toBe('2026-11-01');
    });

    it('accepts an explicit inclusive range', () => {
      const range = resolveDateRange('2026-10-26', '2026-11-01');
      expect(range.days).toBe(7);
      expect(range.start.toISOString()).toBe('2026-10-25T17:00:00.000Z');
      expect(range.end.toISOString()).toBe('2026-11-01T17:00:00.000Z');
    });

    it('rejects malformed, impossible and reversed dates', () => {
      expect(() => resolveDateRange('26-10-01', '2026-10-31')).toThrow(BadRequestException);
      expect(() => resolveDateRange('2026-02-30', '2026-03-05')).toThrow(/hợp lệ/);
      expect(() => resolveDateRange('2026-11-02', '2026-11-01')).toThrow(/không được sau/);
    });

    it('caps the range length', () => {
      expect(() => resolveDateRange('2025-01-01', '2026-12-31')).toThrow(String(MAX_RANGE_DAYS));
      expect(resolveDateRange('2026-01-01', '2026-12-31').days).toBe(365);
    });
  });

  describe('periodKey / enumeratePeriods', () => {
    const lateEvening = new Date('2026-10-31T18:00:00.000Z'); // 01:00 ngày 01/11 giờ VN (Chủ nhật)

    it('buckets by Vietnam-local day, Monday-based week and month', () => {
      expect(periodKey(lateEvening, 'day')).toBe('2026-11-01');
      expect(periodKey(lateEvening, 'week')).toBe('2026-10-26');
      expect(periodKey(lateEvening, 'month')).toBe('2026-11');
    });

    it('lists every period in the range, including empty ones', () => {
      expect(enumeratePeriods(resolveDateRange('2026-10-30', '2026-11-02'), 'day')).toEqual([
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
      ]);
      expect(enumeratePeriods(resolveDateRange('2026-10-26', '2026-11-08'), 'week')).toEqual([
        '2026-10-26',
        '2026-11-02',
      ]);
      expect(enumeratePeriods(resolveDateRange('2026-10-30', '2026-11-02'), 'month')).toEqual([
        '2026-10',
        '2026-11',
      ]);
    });
  });

  describe('capacity helpers', () => {
    it('counts how often each weekday occurs', () => {
      expect(weekdayCounts(resolveDateRange('2026-10-26', '2026-11-01'))).toEqual([1, 1, 1, 1, 1, 1, 1]);
      expect(weekdayCounts(resolveDateRange('2026-10-26', '2026-11-08'))).toEqual([2, 2, 2, 2, 2, 2, 2]);
      expect(weekdayCounts(resolveDateRange('2026-11-01', '2026-11-01'))).toEqual([1, 0, 0, 0, 0, 0, 0]);
    });

    it('parses HH:MM and sums opening hours per weekday', () => {
      expect(timeToHours('18:30')).toBe(18.5);
      const weekly = weeklyOpenHours([
        { dayOfWeek: 1, openTime: '06:00', closeTime: '22:00' },
        { dayOfWeek: 0, openTime: '08:00', closeTime: '12:30' },
        { dayOfWeek: 2, openTime: '10:00', closeTime: '09:00' }, // sai → bỏ qua
      ]);
      expect(weekly).toEqual([4.5, 16, 0, 0, 0, 0, 0]);
    });

    it('computes available hours as Σ open hours × weekday occurrences', () => {
      const weekly = [4.5, 16, 0, 0, 0, 0, 0];
      const counts = weekdayCounts(resolveDateRange('2026-10-26', '2026-11-08'));
      expect(availableHours(weekly, counts)).toBe(41);
    });

    it('clips booked hours to the range', () => {
      const range = resolveDateRange('2026-10-26', '2026-11-01');
      expect(
        bookedHoursInRange(new Date('2026-10-27T01:00:00Z'), new Date('2026-10-27T03:30:00Z'), range),
      ).toBe(2.5);
      expect(
        bookedHoursInRange(new Date('2026-11-01T16:00:00Z'), new Date('2026-11-01T19:00:00Z'), range),
      ).toBe(1);
    });

    it('returns null for ratio without capacity and caps at 1', () => {
      expect(ratio(3, 0)).toBeNull();
      expect(ratio(5, 4)).toBe(1);
      expect(ratio(4, 84)).toBe(0.0476);
    });
  });
});
