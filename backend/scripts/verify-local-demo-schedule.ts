import 'dotenv/config';
import { BookingStatus, PrismaClient } from '@prisma/client';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { vietnamDay, vietnamTime } from '../src/bookings/booking-time';

// Read-only verification of the local API against its database.
const url = new URL(process.env.DATABASE_URL ?? '');
if (!['localhost', '127.0.0.1'].includes(url.hostname) || url.pathname !== '/smatch_db') {
  throw new Error('Local smatch_db only.');
}
const catalog: { id: number; name: string; courts: number }[] = JSON.parse(
  readFileSync(join(__dirname, 'approved-facility-catalog.json'), 'utf8'),
).facilities;
const base = 'http://localhost:3000';
const prisma = new PrismaClient();
type ApiSlot = {
  id: number | null; startTime: string; endTime: string; price: number | null;
  isActive: boolean; isBooked: boolean; status: string;
};

async function main() {
  const requestedDate = process.argv[2] ?? vietnamTime(new Date()).date;
  const firstDay = vietnamDay(requestedDate);
  const facilities = await prisma.facility.findMany({
    where: { id: { in: catalog.map((f) => f.id) } },
    include: { courts: true, operatingHours: true }, orderBy: { id: 'asc' },
  });
  if (facilities.length !== 10) throw new Error('Expected ten facilities.');
  const reports = [];
  for (const facility of facilities) {
    const expected = catalog.find((f) => f.id === facility.id);
    if (!expected || facility.name !== expected.name || facility.courts.length !== expected.courts ||
        !facility.description?.startsWith('S-Match DemoCatalog:') ||
        facility.operatingHours.length !== 7 ||
        facility.operatingHours.some((h) => h.openTime !== '05:00' || h.closeTime !== '23:00')) {
      throw new Error(`Incorrect facility or hours: ${facility.name}`);
    }
    let booked = 0;
    let available = 0;
    let locked = 0;
    for (let offset = 0; offset < 7; offset++) {
      const date = vietnamTime(new Date(firstDay.start.getTime() + offset * 86400000)).date;
      const day = vietnamDay(date);
      let reference: string | null = null;
      for (const court of facility.courts) {
        const response = await fetch(`${base}/facilities/${facility.id}/courts/${court.id}/time-slots/availability?date=${date}`);
        if (!response.ok) throw new Error(`API ${response.status}: ${facility.id}/${court.id}/${date}`);
        const slots = await response.json() as ApiSlot[];
        const bookings = await prisma.booking.findMany({
          where: { courtId: court.id, status: { in: [BookingStatus.PENDING, BookingStatus.CONFIRMED] },
            startTime: { lt: day.end }, endTime: { gt: day.start } },
        });
        const inside = slots.filter((s) => s.startTime >= '05:00' && s.endTime <= '23:00')
          .sort((a, b) => a.startTime.localeCompare(b.startTime));
        let cursor = '05:00';
        for (const slot of inside) {
          if (slot.startTime !== cursor) throw new Error(`Gap/overlap: ${facility.id}/${court.id}/${date} at ${cursor}`);
          cursor = slot.endTime;
          const start = new Date(`${date}T${slot.startTime}:00+07:00`);
          const end = new Date(`${date}T${slot.endTime}:00+07:00`);
          const occupied = bookings.some((b) => b.startTime < end && b.endTime > start);
          if (slot.isBooked !== occupied ||
              slot.status !== (occupied ? 'BOOKED' : slot.isActive ? 'AVAILABLE' : 'LOCKED')) {
            throw new Error(`Wrong status: ${facility.id}/${court.id}/${date}/${slot.startTime}`);
          }
          if (slot.status === 'AVAILABLE' && (slot.id == null || typeof slot.price !== 'number')) {
            throw new Error(`Available slot without tariff: ${facility.id}/${court.id}/${date}`);
          }
          if (slot.status === 'LOCKED') {
            const original = slot.id == null ? null : await prisma.timeSlot.findUnique({ where: { id: slot.id } });
            if (!original || original.isActive) throw new Error(`False lock: ${facility.id}/${court.id}/${date}`);
            locked++;
          }
          if (slot.status === 'BOOKED') booked++;
          if (slot.status === 'AVAILABLE') available++;
        }
        if (cursor !== '23:00') throw new Error(`Missing closing coverage: ${facility.id}/${court.id}/${date}`);
        const closing = slots.find((s) => s.startTime === '23:00' && s.endTime === '24:00');
        if (!closing || closing.status !== 'LOCKED' || closing.isActive) {
          throw new Error(`Closing not locked: ${facility.id}/${court.id}/${date}`);
        }
        const columns = inside.map((s) => `${s.startTime}-${s.endTime}`).join(',');
        if (reference != null && columns !== reference) throw new Error(`Misaligned grid: ${facility.id}/${date}`);
        reference = columns;
      }
    }
    reports.push({ facilityId: facility.id, courts: facility.courts.length, booked, available, locked });
  }
  console.log(JSON.stringify({ from: requestedDate, days: 7, facilities: reports }, null, 2));
}
main().catch((e) => { console.error('Verification failed:', e.message); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
