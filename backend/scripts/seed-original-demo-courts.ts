import { PrismaClient, RoleName } from '@prisma/client';

// Flutter DemoCatalog, in its original order. DemoBookingService defines the slots.
const facilities = [
  ['Hai Chau Badminton', 'Hai Chau', 16.061, 108.2165, 4, 80000],
  ['Hoa Cuong Badminton', 'Hoa Cuong', 16.034, 108.215, 6, 90000],
  ['Thanh Khe Badminton', 'Thanh Khe', 16.064, 108.185, 4, 70000],
  ['An Khe Badminton', 'An Khe', 16.045, 108.178, 3, 70000],
  ['An Hai Badminton', 'An Hai', 16.065, 108.241, 4, 80000],
  ['Son Tra Badminton', 'Son Tra', 16.093, 108.246, 6, 100000],
  ['Ngu Hanh Son Badminton', 'Ngu Hanh Son', 16.012, 108.258, 4, 90000],
  ['Hoa Xuan Badminton', 'Hoa Xuan', 15.999, 108.22, 5, 80000],
  ['Cam Le Badminton', 'Cam Le', 16.012, 108.192, 4, 70000],
  ['Hoa Khanh Badminton', 'Hoa Khanh', 16.073, 108.152, 6, 80000],
] as const;
const marker = 'S-Match DemoCatalog: illustrative listing, not a verified business.';
const url = new URL(process.env.DATABASE_URL ?? '');
const dbName = decodeURIComponent(url.pathname.slice(1));
if (!['localhost', '127.0.0.1', '::1', '[::1]'].includes(url.hostname) ||
    !['smatch_db_migration_test', 'smatch_db'].includes(dbName) ||
    (url.searchParams.get('schema') && url.searchParams.get('schema') !== 'public')) {
  throw new Error('Refusing non-local or non-approved database target.');
}
const ownerEmail = process.env.SMATCH_DEMO_OWNER_EMAIL;
if (!ownerEmail) throw new Error('Set SMATCH_DEMO_OWNER_EMAIL to an existing COURT_OWNER.');
const prisma = new PrismaClient();
async function main() {
  const result = await prisma.$transaction(async tx => {
    await tx.$executeRaw`SELECT pg_advisory_xact_lock(121337818)`;
    const identity = await tx.$queryRaw<{ name: string }[]>`SELECT current_database() AS name`;
    if (identity[0]?.name !== dbName) throw new Error('Database identity mismatch.');
    const owner = await tx.user.findUnique({ where: { email: ownerEmail }, select: { id: true, role: { select: { name: true } } } });
    if (!owner || owner.role.name !== RoleName.COURT_OWNER) throw new Error('Configured owner is missing or is not a COURT_OWNER.');
    let added = 0, unchanged = 0;
    const ids: { name: string; id: number; courts: number }[] = [];
    for (const [name, district, latitude, longitude, count, price] of facilities) {
      const address = `${district}, Da Nang, Vietnam`;
      const matches = await tx.facility.findMany({ where: { name }, include: { courts: { include: { timeSlots: true } }, operatingHours: true } });
      if (matches.length > 1) throw new Error(`Ambiguous facility name: ${name}`);
      const existing = matches[0];
      if (existing) {
        if (existing.ownerId !== owner.id || existing.description !== marker || existing.address !== address || existing.latitude !== latitude || existing.longitude !== longitude || existing.courts.length !== count || existing.operatingHours.length !== 7 || existing.operatingHours.some(h => h.openTime !== '06:00' || h.closeTime !== '22:00')) throw new Error(`Existing facility conflicts with catalogue: ${name}`);
        for (let n = 1; n <= count; n++) {
          const court = existing.courts.find(c => c.name === `Court ${n}`);
          if (!court || court.courtType !== 'INDOOR' || court.status !== 'ACTIVE' || court.timeSlots.length !== 112) throw new Error(`Court conflict: ${name} Court ${n}`);
          for (let day = 0; day < 7; day++) for (let hour = 6; hour < 22; hour++) {
            const start = `${String(hour).padStart(2, '0')}:00`;
            const end = `${String(hour + 1).padStart(2, '0')}:00`;
            if (!court.timeSlots.some(s => s.dayOfWeek === day && s.startTime === start && s.endTime === end && s.price === price + (hour >= 17 ? 20000 : 0) && s.isActive)) throw new Error(`Slot conflict: ${name} Court ${n} day ${day} ${start}`);
          }
        }
        ids.push({ name, id: existing.id, courts: count }); unchanged++; continue;
      }
      const facility = await tx.facility.create({ data: { ownerId: owner.id, name, address, latitude, longitude, description: marker } });
      await tx.operatingHours.createMany({ data: Array.from({ length: 7 }, (_, dayOfWeek) => ({ facilityId: facility.id, dayOfWeek, openTime: '06:00', closeTime: '22:00' })) });
      for (let n = 1; n <= count; n++) {
        const court = await tx.court.create({ data: { facilityId: facility.id, name: `Court ${n}`, courtType: 'INDOOR' } });
        const data = Array.from({ length: 7 }, (_, dayOfWeek) => Array.from({ length: 16 }, (_, i) => {
          const hour = i + 6;
          return { courtId: court.id, dayOfWeek, startTime: `${String(hour).padStart(2, '0')}:00`, endTime: `${String(hour + 1).padStart(2, '0')}:00`, price: price + (hour >= 17 ? 20000 : 0) };
        })).flat();
        await tx.timeSlot.createMany({ data });
      }
      ids.push({ name, id: facility.id, courts: count }); added++;
    }
    return { database: dbName, added, unchanged, facilities: ids };
  }, { isolationLevel: 'Serializable', timeout: 120000 });
  console.log(JSON.stringify(result, null, 2));
}
main().catch(error => { console.error('Seed aborted:', error.message); process.exitCode = 1; }).finally(() => prisma.$disconnect());
