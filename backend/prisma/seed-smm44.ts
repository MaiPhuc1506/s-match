// SMM-44 — Seed bổ sung (additive, idempotent) phục vụ kiểm thử Database & Backend.
//
// KHÔNG thay thế prisma/seed.ts. Chạy SAU seed gốc:
//   npx prisma db seed            (seed gốc: roles, owner@, player@, player2..4@, cơ sở demo)
//   npm run db:seed:smm44         (file này)
//
// Tạo (nếu chưa có):
//   - owner2@smatch.dev
//   - 10 cơ sở cầu lông Đà Nẵng: 6 cơ sở của owner@smatch.dev, 4 cơ sở của owner2@smatch.dev
//   - 2–4 sân/cơ sở (tổng 29 sân), OperatingHours 06:00–22:00 mọi ngày, TimeSlot 4 khung/ngày/sân
//   - player5..player20@smatch.dev (kèm PlayerProfile + toạ độ, Skill, PlayingPreference, Availability)
//   - 30 Booking mẫu: 10 COMPLETED (quá khứ), 15 CONFIRMED (tương lai), 5 CANCELLED
//   - 8 Match mẫu (gắn booking) + participants
//
// Khoá định danh tự nhiên (KHÔNG giả định ID):
//   User -> email | Facility -> (ownerId, name) | Court -> (facilityId, name)
//   TimeSlot -> (courtId, dayOfWeek, startTime) | Booking -> note "SMM44-SEED-BOOKING-nn"
//   Match -> title "SMM44 Seed Match n" | MatchParticipant -> (matchId, userId)
// Chạy lại nhiều lần không tạo bản ghi trùng.

import {
  BookingStatus,
  MatchMode,
  MatchPrivacy,
  MatchPurpose,
  MatchState,
  ParticipantRole,
  ParticipantStatus,
  PrismaClient,
  RoleName,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

const OWNER1_EMAIL = 'owner@smatch.dev';
const OWNER2_EMAIL = 'owner2@smatch.dev';

const SMM44_FACILITIES = [
  { owner: OWNER1_EMAIL, name: 'Hai Chau Badminton', district: 'Hải Châu', lat: 16.061, lon: 108.2165 },
  { owner: OWNER1_EMAIL, name: 'Hoa Cuong Badminton', district: 'Hải Châu', lat: 16.034, lon: 108.215 },
  { owner: OWNER1_EMAIL, name: 'Thanh Khe Badminton', district: 'Thanh Khê', lat: 16.064, lon: 108.185 },
  { owner: OWNER1_EMAIL, name: 'An Khe Badminton', district: 'Thanh Khê', lat: 16.045, lon: 108.178 },
  { owner: OWNER1_EMAIL, name: 'An Hai Badminton', district: 'Sơn Trà', lat: 16.065, lon: 108.241 },
  { owner: OWNER1_EMAIL, name: 'Son Tra Badminton', district: 'Sơn Trà', lat: 16.093, lon: 108.246 },
  { owner: OWNER2_EMAIL, name: 'Ngu Hanh Son Badminton', district: 'Ngũ Hành Sơn', lat: 16.012, lon: 108.258 },
  { owner: OWNER2_EMAIL, name: 'Hoa Xuan Badminton', district: 'Cẩm Lệ', lat: 15.999, lon: 108.22 },
  { owner: OWNER2_EMAIL, name: 'Cam Le Badminton', district: 'Cẩm Lệ', lat: 16.012, lon: 108.192 },
  { owner: OWNER2_EMAIL, name: 'Hoa Khanh Badminton', district: 'Liên Chiểu', lat: 16.073, lon: 108.152 },
] as const;

const SLOT_WINDOWS = [
  { startTime: '06:00', endTime: '08:00', base: 120000 },
  { startTime: '08:00', endTime: '10:00', base: 140000 },
  { startTime: '17:00', endTime: '19:00', base: 200000 },
  { startTime: '19:00', endTime: '21:00', base: 220000 },
] as const;

const PLAYER_FIRST = 5;
const PLAYER_LAST = 20;
const BOOKING_COUNT = 30;

const CENTER = { lat: 16.047079, lon: 108.20623 };

/** Ngày (YYYY-MM-DD) theo giờ Việt Nam, lệch `offsetDays` so với hôm nay. */
function vietnamDate(offsetDays: number): string {
  return new Date(Date.now() + 7 * 3600 * 1000 + offsetDays * 86400000).toISOString().slice(0, 10);
}

function vnInstant(date: string, hhmm: string): Date {
  return new Date(`${date}T${hhmm}:00+07:00`);
}

async function main() {
  const passwordHash = await bcrypt.hash('Password123!', 10);

  // --- Roles + owners -------------------------------------------------------
  const roles = await Promise.all(
    Object.values(RoleName).map((name) =>
      prisma.role.upsert({ where: { name }, update: {}, create: { name } }),
    ),
  );
  const roleId = Object.fromEntries(roles.map((r) => [r.name, r.id])) as Record<RoleName, number>;

  const ownerIds: Record<string, number> = {};
  for (const [email, fullName] of [
    [OWNER1_EMAIL, 'Demo Court Owner'],
    [OWNER2_EMAIL, 'Demo Court Owner 2'],
  ] as const) {
    const owner = await prisma.user.upsert({
      where: { email },
      update: {},
      create: { email, password: passwordHash, fullName, roleId: roleId.COURT_OWNER },
    });
    ownerIds[email] = owner.id;
  }

  // --- Facilities / Courts / OperatingHours / TimeSlots ----------------------
  let courtTotal = 0;
  for (const [index, f] of SMM44_FACILITIES.entries()) {
    const ownerId = ownerIds[f.owner];
    const data = {
      address: `Quận ${f.district}, TP. Đà Nẵng`,
      latitude: f.lat,
      longitude: f.lon,
      contactPhone: `09000000${String(index + 1).padStart(2, '0')}`,
      description: 'Cơ sở mẫu SMM-44 (seed bổ sung)',
    };
    const existing = await prisma.facility.findFirst({ where: { ownerId, name: f.name } });
    const facility = existing
      ? await prisma.facility.update({ where: { id: existing.id }, data })
      : await prisma.facility.create({ data: { ownerId, name: f.name, ...data } });

    for (let dayOfWeek = 0; dayOfWeek <= 6; dayOfWeek += 1) {
      await prisma.operatingHours.upsert({
        where: { facilityId_dayOfWeek: { facilityId: facility.id, dayOfWeek } },
        update: {},
        create: { facilityId: facility.id, dayOfWeek, openTime: '06:00', closeTime: '22:00' },
      });
    }

    const courtCount = 2 + (index % 3); // 2, 3, 4, 2, 3, 4, ... => tổng 29 sân
    for (let n = 1; n <= courtCount; n += 1) {
      const name = `Sân ${n}`;
      const found = await prisma.court.findFirst({ where: { facilityId: facility.id, name } });
      const court =
        found ??
        (await prisma.court.create({
          data: { facilityId: facility.id, name, courtType: n === courtCount && n > 2 ? 'OUTDOOR' : 'INDOOR' },
        }));
      courtTotal += 1;

      await prisma.timeSlot.createMany({
        data: Array.from({ length: 7 }, (_, dayOfWeek) =>
          SLOT_WINDOWS.map((w) => ({
            courtId: court.id,
            dayOfWeek,
            startTime: w.startTime,
            endTime: w.endTime,
            price: w.base + (dayOfWeek === 0 || dayOfWeek === 6 ? 20000 : 0),
          })),
        ).flat(),
        skipDuplicates: true,
      });
    }
  }

  // --- Players 5..20 ----------------------------------------------------------
  const playerIds: number[] = [];
  for (let i = PLAYER_FIRST; i <= PLAYER_LAST; i += 1) {
    const email = `player${i}@smatch.dev`;
    const user = await prisma.user.upsert({
      where: { email },
      update: {},
      create: { email, password: passwordHash, fullName: `Demo Player ${i}`, roleId: roleId.PLAYER },
    });
    playerIds.push(user.id);

    // Toạ độ tất định quanh trung tâm Đà Nẵng (±~5.5 km) để test PostGIS / geo search.
    const latitude = Number((CENTER.lat + ((i * 7919) % 200 - 100) / 2000).toFixed(6));
    const longitude = Number((CENTER.lon + ((i * 104729) % 200 - 100) / 2000).toFixed(6));
    const skillValue = (k: number) => 1.5 + ((i * k) % 7) * 0.5; // 1.5 .. 4.5

    const profile = await prisma.playerProfile.upsert({
      where: { userId: user.id },
      update: { latitude, longitude, locationUpdatedAt: new Date() },
      create: {
        userId: user.id,
        nickname: `Player ${i}`,
        skillLevel: skillValue(3) >= 3.5 ? 'ADVANCED' : skillValue(3) >= 2.5 ? 'INTERMEDIATE' : 'BEGINNER',
        gender: i % 2 === 0 ? 'FEMALE' : 'MALE',
        latitude,
        longitude,
        locationUpdatedAt: new Date(),
      },
    });

    await prisma.skill.upsert({
      where: { playerProfileId: profile.id },
      update: {},
      create: {
        playerProfileId: profile.id,
        smash: skillValue(2),
        defense: skillValue(3),
        netPlay: skillValue(5),
        stamina: skillValue(4),
        footwork: skillValue(6),
        serve: skillValue(1),
      },
    });

    await prisma.playingPreference.upsert({
      where: { userId: user.id },
      update: {},
      create: {
        userId: user.id,
        preferredMode: i % 2 === 0 ? MatchMode.SINGLES : MatchMode.DOUBLES,
        purpose: MatchPurpose.CASUAL,
        minSkillLevel: 1 + (i % 2),
        maxSkillLevel: 4 + (i % 2),
        maxDistanceKm: 10 + (i % 3) * 5,
      },
    });

    for (const slot of [
      { dayOfWeek: 1, startTime: '18:00', endTime: '21:00' },
      { dayOfWeek: 6, startTime: '08:00', endTime: '11:00' },
    ]) {
      await prisma.availability.upsert({
        where: { userId_dayOfWeek_startTime: { userId: user.id, dayOfWeek: slot.dayOfWeek, startTime: slot.startTime } },
        update: {},
        create: { userId: user.id, ...slot },
      });
    }
  }

  // --- 30 bookings (10 COMPLETED quá khứ, 15 CONFIRMED tương lai, 5 CANCELLED) ----
  const courts = await prisma.court.findMany({
    where: { facility: { name: { in: SMM44_FACILITIES.map((f) => f.name) } } },
    orderBy: { id: 'asc' },
  });

  const bookingIds: number[] = [];
  for (let k = 0; k < BOOKING_COUNT; k += 1) {
    const note = `SMM44-SEED-BOOKING-${String(k + 1).padStart(2, '0')}`;
    const existing = await prisma.booking.findFirst({ where: { note } });
    if (existing) {
      bookingIds.push(existing.id);
      continue;
    }

    // Mỗi booking một ngày riêng => không bao giờ chồng lấn (kể cả khi đã có exclusion constraint).
    const past = k < 10;
    const future = k >= 10 && k < 25;
    const dayOffset = past ? -(k + 1) : future ? k - 9 : k - 24;
    const date = vietnamDate(dayOffset);
    const [from, to] = past || future ? ['18:00', '20:00'] : ['19:00', '21:00'];
    const status = past ? BookingStatus.COMPLETED : future ? BookingStatus.CONFIRMED : BookingStatus.CANCELLED;

    const created = await prisma.booking.create({
      data: {
        userId: playerIds[k % playerIds.length],
        courtId: courts[(k * 3) % courts.length].id,
        startTime: vnInstant(date, from),
        endTime: vnInstant(date, to),
        totalPrice: 420000,
        status,
        note,
      },
    });
    bookingIds.push(created.id);
  }

  // --- 8 matches gắn booking --------------------------------------------------
  // m0..m4 -> booking tương lai (k=10..14); m5,m6 -> booking quá khứ (k=0,1); m7 -> booking đã huỷ (k=25)
  const matchPlan: { bookingIndex: number; status: MatchState; privacy: MatchPrivacy; extraAccepted: number; requested: boolean }[] = [
    { bookingIndex: 10, status: MatchState.OPEN, privacy: MatchPrivacy.OPEN, extraAccepted: 1, requested: true },
    { bookingIndex: 11, status: MatchState.OPEN, privacy: MatchPrivacy.OPEN, extraAccepted: 0, requested: true },
    { bookingIndex: 12, status: MatchState.OPEN, privacy: MatchPrivacy.OPEN, extraAccepted: 2, requested: false },
    { bookingIndex: 13, status: MatchState.FULL, privacy: MatchPrivacy.OPEN, extraAccepted: 3, requested: false },
    { bookingIndex: 14, status: MatchState.OPEN, privacy: MatchPrivacy.PRIVATE, extraAccepted: 1, requested: false },
    { bookingIndex: 0, status: MatchState.COMPLETED, privacy: MatchPrivacy.OPEN, extraAccepted: 3, requested: false },
    { bookingIndex: 1, status: MatchState.COMPLETED, privacy: MatchPrivacy.OPEN, extraAccepted: 3, requested: false },
    { bookingIndex: 25, status: MatchState.CANCELLED, privacy: MatchPrivacy.OPEN, extraAccepted: 0, requested: false },
  ];

  for (const [m, plan] of matchPlan.entries()) {
    const title = `SMM44 Seed Match ${m + 1}`;
    if (await prisma.match.findFirst({ where: { title } })) continue;

    const booking = await prisma.booking.findUniqueOrThrow({
      where: { id: bookingIds[plan.bookingIndex] },
      include: { court: { include: { facility: true } } },
    });
    // Mỗi booking chỉ gắn được 1 match (Match.bookingId UNIQUE)
    if (await prisma.match.findUnique({ where: { bookingId: booking.id } })) continue;

    const match = await prisma.match.create({
      data: {
        title,
        description: 'Trận mẫu SMM-44',
        privacy: plan.privacy,
        status: plan.status,
        mode: MatchMode.DOUBLES,
        purpose: MatchPurpose.CASUAL,
        hostId: booking.userId,
        bookingId: booking.id,
        startTime: booking.startTime,
        endTime: booking.endTime,
        location: `${booking.court.facility.name} - ${booking.court.name}`,
        maxPlayers: 4,
        feePerPlayer: booking.totalPrice / 4,
      },
    });

    await prisma.matchParticipant.create({
      data: { matchId: match.id, userId: booking.userId, role: ParticipantRole.HOST, status: ParticipantStatus.ACCEPTED },
    });

    const others = playerIds.filter((id) => id !== booking.userId);
    for (let a = 0; a < plan.extraAccepted; a += 1) {
      await prisma.matchParticipant.create({
        data: { matchId: match.id, userId: others[(m + a) % others.length], role: ParticipantRole.MEMBER, status: ParticipantStatus.ACCEPTED },
      });
    }
    if (plan.requested) {
      await prisma.matchParticipant.create({
        data: { matchId: match.id, userId: others[(m + 7) % others.length], role: ParticipantRole.MEMBER, status: ParticipantStatus.REQUESTED },
      });
    }
  }

  const summary = {
    facilities: await prisma.facility.count({ where: { name: { in: SMM44_FACILITIES.map((f) => f.name) } } }),
    courtsTouched: courtTotal,
    players: await prisma.user.count({ where: { email: { startsWith: 'player', endsWith: '@smatch.dev' } } }),
    seedBookings: await prisma.booking.count({ where: { note: { startsWith: 'SMM44-SEED-BOOKING-' } } }),
    seedMatches: await prisma.match.count({ where: { title: { startsWith: 'SMM44 Seed Match ' } } }),
  };
  console.log('SMM-44 seed completed:', summary);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
