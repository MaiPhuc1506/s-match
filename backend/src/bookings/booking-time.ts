import { BadRequestException } from '@nestjs/common';

// Facilities currently operate in Vietnam. Compare instants in one business
// timezone, independent of the host timezone or the client's ISO offset.
export function vietnamTime(date: Date) {
  const local = new Date(date.getTime() + 7 * 60 * 60 * 1000);
  return {
    date: local.toISOString().slice(0, 10),
    dayOfWeek: local.getUTCDay(),
    time: local.toISOString().slice(11, 16),
  };
}

export function vietnamDay(date: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date ?? '')) {
    throw new BadRequestException('Ngày phải theo định dạng YYYY-MM-DD');
  }
  const start = new Date(`${date}T00:00:00+07:00`);
  if (Number.isNaN(start.getTime()) || vietnamTime(start).date !== date) {
    throw new BadRequestException('Ngày không hợp lệ');
  }
  return { start, end: new Date(start.getTime() + 86400000), dayOfWeek: vietnamTime(start).dayOfWeek };
}
