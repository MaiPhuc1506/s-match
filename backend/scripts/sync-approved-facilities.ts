import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
const prisma = new PrismaClient();
const catalog = JSON.parse(
  readFileSync(join(__dirname, 'approved-facility-catalog.json'), 'utf8'),
).facilities;
const minutes = (s: string) => {
  const [h, m] = s.split(':').map(Number);
  return h * 60 + m;
};
const time = (n: number) =>
  `${String(Math.floor(n / 60)).padStart(2, '0')}:${String(n % 60).padStart(2, '0')}`;
async function main() {
  const url = new URL(process.env.DATABASE_URL!);
  if (
    !['localhost', '127.0.0.1'].includes(url.hostname) ||
    url.pathname !== '/smatch_db'
  )
    throw Error('Local smatch_db only');
  const before = await prisma.facility.findMany({
    where: { id: { in: catalog.map((f: any) => f.id) } },
    include: {
      courts: { include: { timeSlots: true, bookings: true } },
      operatingHours: true,
      services: true,
    },
  });
  writeFileSync(
    `/private/tmp/smatch-facilities-before-${Date.now()}.json`,
    JSON.stringify(before, null, 2),
    { mode: 0o600 },
  );
  const results = await prisma.$transaction(
    async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(121337818)`;
      const result = [];
      for (const f of catalog) {
        const current = await tx.facility.findUnique({
          where: { id: f.id },
          include: { courts: true },
        });
        if (
          !current ||
          current.name !== f.name ||
          current.courts.length !== f.courts ||
          !current.description?.startsWith('S-Match DemoCatalog:')
        )
          throw Error(`Identity mismatch: ${f.name}`);
        const ranges = f.illustrativeTariffs;
        const [openTime, closeTime] = f.illustrativeHours.split('–');
        if (
          ranges[0].range.split('–')[0] !== openTime ||
          ranges.at(-1).range.split('–')[1] !== closeTime
        )
          throw Error('Hours mismatch');
        for (let d = 0; d < 7; d++)
          await tx.operatingHours.upsert({
            where: { facilityId_dayOfWeek: { facilityId: f.id, dayOfWeek: d } },
            create: { facilityId: f.id, dayOfWeek: d, openTime, closeTime },
            update: { openTime, closeTime },
          });
        for (const court of current.courts) {
          // Serialize with booking creation. Existing booking instants and amounts stay untouched.
          await tx.$queryRaw`SELECT id FROM "Court" WHERE id = ${court.id} FOR UPDATE`;
          await tx.timeSlot.updateMany({
            where: { courtId: court.id },
            data: { isActive: false },
          });
          for (let dayOfWeek = 0; dayOfWeek < 7; dayOfWeek++)
            for (const range of ranges) {
              const [a, b] = range.range.split('–').map(minutes);
              for (let start = a; start < b; start += 60) {
                const end = Math.min(start + 60, b),
                  fraction = (end - start) / 60;
                const data = {
                  endTime: time(end),
                  price: Math.round(range.fixedVndPerHour * fraction),
                  hourlyRate: range.fixedVndPerHour,
                  walkInPrice: Math.round(range.walkInVndPerHour * fraction),
                  isActive: true,
                };
                await tx.timeSlot.upsert({
                  where: {
                    courtId_dayOfWeek_startTime: {
                      courtId: court.id,
                      dayOfWeek,
                      startTime: time(start),
                    },
                  },
                  create: {
                    courtId: court.id,
                    dayOfWeek,
                    startTime: time(start),
                    ...data,
                  },
                  update: data,
                });
              }
            }
        }
        for (const [sortOrder, s] of f.illustrativeServices.entries()) {
          const sourceKey = `approved-figma-${sortOrder}`;
          const data = {
            name: s.name,
            price: s.priceVnd,
            unit: s.unit,
            category: 'BEVERAGE',
            sortOrder,
          };
          await tx.facilityService.upsert({
            where: { facilityId_sourceKey: { facilityId: f.id, sourceKey } },
            create: { facilityId: f.id, sourceKey, ...data },
            update: data,
          });
        }
        result.push({
          id: f.id,
          name: f.name,
          courts: f.courts,
          hours: f.illustrativeHours,
          ranges: ranges.length,
          services: f.illustrativeServices.length,
        });
      }
      return result;
    },
    { timeout: 120000, isolationLevel: 'Serializable' },
  );
  console.log(JSON.stringify(results, null, 2));
}
main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
