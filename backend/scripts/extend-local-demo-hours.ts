import 'dotenv/config';
import { Prisma, PrismaClient } from '@prisma/client';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Changes only the ten marked local demo facilities, retaining bookings and
// existing slot prices/locks. Take a full backup before running.
const url = new URL(process.env.DATABASE_URL ?? '');
if (!['localhost', '127.0.0.1'].includes(url.hostname) ||
    url.pathname !== '/smatch_db' ||
    (url.searchParams.get('schema') && url.searchParams.get('schema') !== 'public')) {
  throw new Error('Refusing anything other than local smatch_db/public.');
}
const catalog: { id: number; name: string; courts: number }[] = JSON.parse(
  readFileSync(join(__dirname, 'approved-facility-catalog.json'), 'utf8'),
).facilities;
const prisma = new PrismaClient();
const minutes = (time: string) => {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
};
const time = (n: number) => `${String(Math.floor(n / 60)).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`;
const overlaps = (a: { startTime: string; endTime: string }, b: { startTime: string; endTime: string }) =>
  a.startTime < b.endTime && a.endTime > b.startTime;

async function main() {
  const result = await prisma.$transaction(async (tx) => {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(121337818)`;
    const identity = await tx.$queryRaw<{ name: string }[]>`SELECT current_database() AS name`;
    if (identity[0]?.name !== 'smatch_db' || catalog.length !== 10) throw new Error('Database/catalog identity mismatch.');
    const facilities = await tx.facility.findMany({
      where: { id: { in: catalog.map((f) => f.id) } },
      include: { courts: { orderBy: { id: 'asc' } }, operatingHours: true },
      orderBy: { id: 'asc' },
    });
    if (facilities.length !== 10) throw new Error('Expected ten facilities.');
    for (const expected of catalog) {
      const f = facilities.find((item) => item.id === expected.id);
      if (!f || f.name !== expected.name || !f.description?.startsWith('S-Match DemoCatalog:') ||
          f.courts.length !== expected.courts || f.operatingHours.length !== 7) {
        throw new Error(`Demo identity/configuration mismatch: ${expected.name}`);
      }
    }
    for (const court of facilities.flatMap((f) => f.courts).sort((a, b) => a.id - b.id)) {
      await tx.$queryRaw`SELECT id FROM "Court" WHERE id = ${court.id} FOR UPDATE`;
    }
    let added = 0;
    let retainedLocks = 0;
    for (const facility of facilities) {
      for (const hours of facility.operatingHours) {
        const oldOpen = minutes(hours.openTime);
        const oldClose = minutes(hours.closeTime);
        if (oldOpen < 300 || oldOpen >= 1380 || oldClose <= oldOpen || oldClose > 1440) {
          throw new Error(`Unsupported existing hours: ${facility.name} day ${hours.dayOfWeek}`);
        }
        for (const court of facility.courts) {
          const slots = await tx.timeSlot.findMany({
            where: { courtId: court.id, dayOfWeek: hours.dayOfWeek }, orderBy: { startTime: 'asc' },
          });
          const active = slots.filter((s) => s.isActive &&
            minutes(s.startTime) >= oldOpen && minutes(s.endTime) <= oldClose);
          if (active.length === 0) throw new Error(`No tariff to extend: ${facility.name} / ${court.name}`);
          const ranges = [
            { start: 300, end: oldOpen, source: active[0] },
            { start: oldClose, end: 1380, source: active[active.length - 1] },
          ];
          for (const range of ranges) {
            const sourceDuration = minutes(range.source.endTime) - minutes(range.source.startTime);
            const fixedRate = range.source.hourlyRate ?? range.source.price * 60 / sourceDuration;
            const walkRate = range.source.walkInPrice == null ? null : range.source.walkInPrice * 60 / sourceDuration;
            if (sourceDuration <= 0 || !Number.isFinite(fixedRate) || fixedRate < 0) throw new Error('Invalid source tariff.');
            for (let start = range.start; start < range.end; start += 60) {
              const end = Math.min(start + 60, range.end);
              if (end - start < 30) throw new Error('Extension would create an unbookable fragment.');
              const target = { startTime: time(start), endTime: time(end) };
              if (slots.some((s) => s.isActive && overlaps(s, target))) {
                throw new Error(`Existing active slot overlaps extension: ${facility.name} / ${court.name}`);
              }
              const possibleLock = slots.some((s) => !s.isActive && overlaps(s, target) &&
                !active.some((a) => overlaps(a, s)));
              if (possibleLock) { retainedLocks++; continue; }
              if (slots.some((s) => s.startTime === target.startTime)) {
                // Never reactivate a pre-existing inactive record.
                retainedLocks++;
                continue;
              }
              await tx.timeSlot.create({ data: {
                courtId: court.id, dayOfWeek: hours.dayOfWeek, ...target,
                price: Math.round(fixedRate * (end - start) / 60),
                hourlyRate: fixedRate,
                walkInPrice: walkRate == null ? null : Math.round(walkRate * (end - start) / 60),
                isActive: true,
              } });
              added++;
            }
          }
        }
        await tx.operatingHours.update({
          where: { id: hours.id }, data: { openTime: '05:00', closeTime: '23:00' },
        });
      }
    }
    return { facilities: facilities.length, addedSlots: added, retainedLocks };
  }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable, timeout: 120000 });
  console.log(JSON.stringify(result, null, 2));
}
main().catch((e) => { console.error('Local hours update aborted:', e.message); process.exitCode = 1; })
  .finally(() => prisma.$disconnect());
