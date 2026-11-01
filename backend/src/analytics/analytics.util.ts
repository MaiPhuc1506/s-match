import { BadRequestException } from '@nestjs/common';

export const VN_UTC_OFFSET_MINUTES = 7 * 60;
export const DEFAULT_RANGE_DAYS = 30;
export const MAX_RANGE_DAYS = 366;

const MINUTE_MS = 60_000;
const HOUR_MS = 3_600_000;
const DAY_MS = 86_400_000;
const OFFSET_MS = VN_UTC_OFFSET_MINUTES * MINUTE_MS;

export type Granularity = 'day' | 'week' | 'month';

export interface DateRange {
  start: Date;
  end: Date;
  fromDate: string;
  toDate: string;
  days: number;
  fromLocalMs: number;
}

const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

export const round = (value: number, digits = 2): number => {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
};

export const ratio = (used: number, capacity: number): number | null =>
  capacity > 0 ? round(Math.min(1, used / capacity), 4) : null;

const formatLocalDate = (localMs: number): string => new Date(localMs).toISOString().slice(0, 10);

function parseLocalDate(value: string, field: string): number {
  const match = DATE_PATTERN.exec(value);
  if (!match) {
    throw new BadRequestException(`${field} phải có định dạng YYYY-MM-DD`);
  }
  const localMs = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
  if (formatLocalDate(localMs) !== value) {
    throw new BadRequestException(`${field} không phải là ngày hợp lệ`);
  }
  return localMs;
}

export function resolveDateRange(from?: string, to?: string, now: Date = new Date()): DateRange {
  const todayLocalMs = Math.floor((now.getTime() + OFFSET_MS) / DAY_MS) * DAY_MS;

  const toLocalMs = to ? parseLocalDate(to, 'to') : todayLocalMs;
  const fromLocalMs = from
    ? parseLocalDate(from, 'from')
    : toLocalMs - (DEFAULT_RANGE_DAYS - 1) * DAY_MS;

  if (fromLocalMs > toLocalMs) {
    throw new BadRequestException('from không được sau to');
  }
  const days = Math.round((toLocalMs - fromLocalMs) / DAY_MS) + 1;
  if (days > MAX_RANGE_DAYS) {
    throw new BadRequestException(`Khoảng thời gian tối đa là ${MAX_RANGE_DAYS} ngày`);
  }

  return {
    start: new Date(fromLocalMs - OFFSET_MS),
    end: new Date(toLocalMs + DAY_MS - OFFSET_MS),
    fromDate: formatLocalDate(fromLocalMs),
    toDate: formatLocalDate(toLocalMs),
    days,
    fromLocalMs,
  };
}

function periodKeyFromLocal(localMs: number, granularity: Granularity): string {
  if (granularity === 'month') return formatLocalDate(localMs).slice(0, 7);
  if (granularity === 'week') {
    const dayOfWeek = new Date(localMs).getUTCDay(); // 0 = Chủ nhật
    return formatLocalDate(localMs - ((dayOfWeek + 6) % 7) * DAY_MS); // tuần bắt đầu từ Thứ 2
  }
  return formatLocalDate(localMs);
}

export function periodKey(instant: Date, granularity: Granularity): string {
  return periodKeyFromLocal(instant.getTime() + OFFSET_MS, granularity);
}

export function enumeratePeriods(range: DateRange, granularity: Granularity): string[] {
  const keys: string[] = [];
  for (let i = 0; i < range.days; i++) {
    const key = periodKeyFromLocal(range.fromLocalMs + i * DAY_MS, granularity);
    if (keys[keys.length - 1] !== key) keys.push(key);
  }
  return keys;
}

export function weekdayCounts(range: DateRange): number[] {
  const counts = new Array<number>(7).fill(0);
  for (let i = 0; i < range.days; i++) {
    counts[new Date(range.fromLocalMs + i * DAY_MS).getUTCDay()]++;
  }
  return counts;
}

export function timeToHours(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours + (minutes || 0) / 60;
}

export function weeklyOpenHours(
  operatingHours: { dayOfWeek: number; openTime: string; closeTime: string }[],
): number[] {
  const weekly = new Array<number>(7).fill(0);
  for (const slot of operatingHours) {
    const hours = timeToHours(slot.closeTime) - timeToHours(slot.openTime);
    if (slot.dayOfWeek >= 0 && slot.dayOfWeek <= 6 && Number.isFinite(hours) && hours > 0) {
      weekly[slot.dayOfWeek] += hours;
    }
  }
  return weekly;
}

export function availableHours(weeklyHours: number[], counts: number[]): number {
  return weeklyHours.reduce((sum, hours, day) => sum + hours * counts[day], 0);
}

export function bookedHoursInRange(startTime: Date, endTime: Date, range: DateRange): number {
  const start = Math.max(startTime.getTime(), range.start.getTime());
  const end = Math.min(endTime.getTime(), range.end.getTime());
  return Math.max(0, end - start) / HOUR_MS;
}
