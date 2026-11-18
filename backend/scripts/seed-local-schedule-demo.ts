import 'dotenv/config';
import { BookingStatus, Prisma, PrismaClient, RoleName } from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import * as bcrypt from 'bcrypt';
import { vietnamDay, vietnamTime } from '../src/bookings/booking-time';

// Local-only, idempotent demo data. Never edits or deletes existing bookings.
const url = new URL(process.env.DATABASE_URL ?? '');
if (!['localhost', '127.0.0.1'].includes(url.hostname) ||
    url.pathname !== '/smatch_db' ||
    (url.searchParams.get('schema') && url.searchParams.get('schema') !== 'public')) {
  throw new Error('Refusing anything other than local smatch_db/public.');
}
const catalog: { id: number; name: string; courts: number }[] = JSON.parse(
  readFileSync(join(__dirname, 'approved-facility-catalog.json'), 'utf8'),
).facilities;
const marker = 'S-Match DemoCatalog:';
const email = 'schedule-demo@local.invalid';
const note = 'S-Match local schedule demo seed';
const prisma = new PrismaClient();

async function main() {
  const password = await bcrypt.hash(randomBytes(32).toString('hex'), 10);
  const result = await prisma.$transaction(async (tx) => {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(121337818)`;
    const identity = await tx.$queryRaw<{ name: string }[]>`SELECT current_database() AS name`;
    if (identity[0]?.name !== 'smatch_db') throw new Error('Database identity mismatch.');
    const facilities = await tx.facility.findMany({
      where: { id: { in: catalog.map((f) => f.id) } },
      include: { courts: { orderBy: { id: 'asc' } }, operatingHours: true },
      orderBy: { id: 'asc' },
    });
    if (facilities.length !== 10 || catalog.length !== 10) throw new Error('Expected 10 demo facilities.');
    for (const expected of catalog) {
      const f = facilities.find((item) => item.id === expected.id);
      if (!f || f.name !== expected.name || !f.description?.startsWith(marker) ||
          f.courts.length !== expected.courts || f.operatingHours.length !== 7 ||
          f.courts.some((c) => c.status !== 'ACTIVE')) {
        throw new Error(`Demo facility identity/configuration mismatch: ${expected.name}`);
      }
    }
    // Coordinate with normal booking creation before changing hours or checking overlaps.
    for (const court of facilities.flatMap((f) => f.courts).sort((a, b) => a.id - b.id)) {
      await tx.$queryRaw`SELECT id FROM "Court" WHERE id = ${court.id} FOR UPDATE`;
    }
    const changedHours = await tx.operatingHours.updateMany({
      where: { facilityId: { in: catalog.map((f) => f.id) }, closeTime: { gt: '23:00' } },
      data: { closeTime: '23:00' },
    });
    const role = await tx.role.findUnique({ where: { name: RoleName.PLAYER } });
    if (!role) throw new Error('PLAYER role missing.');
    let user = await tx.user.findUnique({ where: { email } });
    if (user && (user.fullName !== 'Local Schedule Demo' || user.roleId !== role.id)) {
      throw new Error('Demo user email is already in use.');
    }
    user ??= await tx.user.create({ data: {
      email, password, fullName: 'Local Schedule Demo', roleId: role.id,
    } });

    const today = vietnamDay(vietnamTime(new Date()).date);
    let created = 0;
    let existing = 0;
    for (let offset = 0; offset < 7; offset++) {
      const day = vietnamTime(new Date(today.start.getTime() + offset * 86400000));
      for (const facility of facilities) {
        for (const [index, preferred] of ['18:00', '20:00'].entries()) {
          const court = facility.courts[index];
          const dayRange = vietnamDay(day.date);
          const alreadySeeded = await tx.booking.findFirst({
            where: { courtId: court.id, userId: user.id, note,
              status: { in: [BookingStatus.PENDING, BookingStatus.CONFIRMED] },
              startTime: { gte: dayRange.start, lt: dayRange.end } },
          });
          if (alreadySeeded) { existing++; continue; }
          const hours = facility.operatingHours.find((h) => h.dayOfWeek === day.dayOfWeek)!;
          const slots = await tx.timeSlot.findMany({
            where: { courtId: court.id, dayOfWeek: day.dayOfWeek, isActive: true,
              startTime: { gte: hours.openTime }, endTime: { lte: hours.closeTime < '23:00' ? hours.closeTime : '23:00' } },
            orderBy: { startTime: 'asc' },
          });
          const candidates = slots
            .filter((slot) => {
              const duration = (new Date(`2000-01-01T${slot.endTime}:00Z`).getTime() -
                new Date(`2000-01-01T${slot.startTime}:00Z`).getTime()) / 60000;
              return duration >= 30 && duration <= 60 && Number.isFinite(slot.price) && slot.price >= 0;
            })
            .sort((a, b) => Math.abs(toMinutes(a.startTime) - toMinutes(preferred)) -
              Math.abs(toMinutes(b.startTime) - toMinutes(preferred)));
          let inserted = false;
          for (const slot of candidates) {
            const startTime = new Date(`${day.date}T${slot.startTime}:00+07:00`);
            const endTime = new Date(`${day.date}T${slot.endTime}:00+07:00`);
            const conflict = await tx.booking.findFirst({
              where: { courtId: court.id, status: { in: [BookingStatus.PENDING, BookingStatus.CONFIRMED] },
                startTime: { lt: endTime }, endTime: { gt: startTime } },
            });
            if (conflict) continue;
            await tx.booking.create({ data: {
              userId: user.id, courtId: court.id, startTime, endTime,
              totalPrice: slot.price, status: BookingStatus.CONFIRMED, note,
            } });
            created++;
            inserted = true;
            break;
          }
          if (!inserted) throw new Error(`No conflict-free slot for ${facility.name}, court ${court.id}, ${day.date}.`);
        }
      }
    }
    return { database: 'smatch_db', firstDate: vietnamTime(today.start).date,
      days: 7, facilities: facilities.length, created, existing, changedHours: changedHours.count };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable, timeout: 120000 });
  console.log(JSON.stringify(result, null, 2));
}

function toMinutes(time: string) {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

main().catch((error) => { console.error('Local demo seed aborted:', error.message); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
