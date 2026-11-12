import { BookingStatus, Prisma, PrismaClient, RoleName } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { haversineKm } from '../candidates/geo.util';

// SMM-44 — Database & Backend Feature Testing (kiểm thử trực tiếp trên PostgreSQL thật).
//
// Opt-in: RUN_DB_LIVE=1. Mặc định bị skip nên `npm test` thường không đụng DB.
// PostGIS: thêm SMM44_POSTGIS=1 (script db:verify:clean tự đặt khi tạo được extension).
//
// Spec CHỈ ghi các bản ghi có tiền tố riêng (smm44-<uuid>) và xoá chúng khi xong.
// Không migrate, không reset, không seed, không xoá dữ liệu có sẵn.
// Phần "seed data" chỉ ĐỌC dữ liệu do prisma/seed.ts + prisma/seed-smm44.ts tạo.
const enabled = process.env.RUN_DB_LIVE === '1';
const live = enabled ? describe : describe.skip;
const livePostgis = enabled && process.env.SMM44_POSTGIS === '1' ? describe : describe.skip;

const TOWN = [
  { owner: 'owner@smatch.dev', names: ['Hai Chau Badminton', 'Hoa Cuong Badminton', 'Thanh Khe Badminton', 'An Khe Badminton', 'An Hai Badminton', 'Son Tra Badminton'] },
  { owner: 'owner2@smatch.dev', names: ['Ngu Hanh Son Badminton', 'Hoa Xuan Badminton', 'Cam Le Badminton', 'Hoa Khanh Badminton'] },
];
const ALL_FACILITY_NAMES = TOWN.flatMap((t) => t.names);

const EXPECTED_TABLES = [
  'Role', 'User', 'RefreshSession', 'PlayerProfile', 'Skill', 'PlayingPreference', 'Availability',
  'Facility', 'Court', 'TimeSlot', 'OperatingHours', 'Booking', 'Match', 'MatchParticipant', 'Feedback',
  'RecommendationSession', 'RecommendationResult', 'PlayerRating', 'RatingHistory',
];

const SMM44_CONSTRAINTS = [
  'Booking_time_order_check', 'Booking_totalPrice_check', 'Booking_no_overlap_excl',
  'TimeSlot_dayOfWeek_check', 'TimeSlot_time_order_check', 'TimeSlot_price_check',
  'OperatingHours_dayOfWeek_check', 'OperatingHours_time_order_check',
  'Availability_dayOfWeek_check', 'Availability_time_order_check',
  'PlayingPreference_skill_range_check', 'PlayingPreference_maxDistanceKm_check',
  'Facility_latitude_check', 'Facility_longitude_check',
  'PlayerProfile_latitude_check', 'PlayerProfile_longitude_check',
  'Match_time_order_check', 'Match_maxPlayers_check', 'Match_skill_range_check',
  'Feedback_rating_check', 'Feedback_no_self_feedback_check', 'RecommendationResult_rank_check',
  // đã có từ migration SMM-36
  'PlayerRating_score_check', 'PlayerRating_no_self_rating_check',
];

/** Thời điểm cố định ở tương lai xa (UTC) để không đụng dữ liệu thật. */
const at = (day: number, hhmm: string) => new Date(`2036-03-${String(day).padStart(2, '0')}T${hhmm}:00.000Z`);

/** Chấp nhận lỗi nếu nhắc tên constraint, hoặc là lỗi check/exclusion chuẩn của PostgreSQL. */
async function expectDbRejects(op: () => Promise<unknown>, constraint: string) {
  let error: unknown;
  try {
    await op();
  } catch (e) {
    error = e;
  }
  expect(error).toBeDefined();
  const meta = (error as { meta?: unknown })?.meta;
  const text = `${(error as Error)?.message ?? ''} ${meta ? JSON.stringify(meta) : ''}`;
  const generic = /23514|23P01|P2004|violates (check|exclusion) constraint|conflicting key value/i;
  expect(text.includes(constraint) || generic.test(text)).toBe(true);
}

live('SMM-44 Database integrity (real PostgreSQL)', () => {
  jest.setTimeout(60000);

  let prisma: PrismaClient;
  const tag = `smm44-${randomUUID().slice(0, 8)}`;
  const createdUserIds: number[] = [];
  let dayCursor = 1;

  const ctx = {
    ownerId: 0,
    playerId: 0,
    player2Id: 0,
    noProfileUserId: 0,
    facilityId: 0,
    courtId: 0,
    matchId: 0,
    recSessionId: 0,
  };

  async function makeUser(label: string, roleName: RoleName = RoleName.PLAYER) {
    const role = await prisma.role.upsert({ where: { name: roleName }, update: {}, create: { name: roleName } });
    const user = await prisma.user.create({
      data: { email: `${tag}-${label}@example.test`, password: 'not-a-real-hash', roleId: role.id },
    });
    createdUserIds.push(user.id);
    return user;
  }

  async function makeCourt(name = `${tag}-court-${Math.random().toString(36).slice(2, 7)}`) {
    return prisma.court.create({ data: { facilityId: ctx.facilityId, name } });
  }

  /** Mỗi test dùng một ngày riêng để các test độc lập với nhau. */
  const nextDay = () => {
    dayCursor += 1;
    return dayCursor;
  };

  const book = (
    courtId: number,
    start: Date,
    end: Date,
    status: BookingStatus = BookingStatus.CONFIRMED,
    userId = ctx.playerId,
  ) => prisma.booking.create({ data: { userId, courtId, startTime: start, endTime: end, totalPrice: 100000, status } });

  beforeAll(async () => {
    prisma = new PrismaClient();
    await prisma.$connect();

    const owner = await makeUser('owner', RoleName.COURT_OWNER);
    const player = await makeUser('player');
    const player2 = await makeUser('player2');
    const noProfile = await makeUser('noprofile');
    ctx.ownerId = owner.id;
    ctx.playerId = player.id;
    ctx.player2Id = player2.id;
    ctx.noProfileUserId = noProfile.id;

    const facility = await prisma.facility.create({
      data: { ownerId: owner.id, name: `${tag} facility (no coordinates)`, address: 'SMM-44 test-only facility' },
    });
    ctx.facilityId = facility.id;
    ctx.courtId = (await makeCourt()).id;

    const match = await prisma.match.create({
      data: { title: `${tag} match`, hostId: owner.id, startTime: at(1, '10:00'), endTime: at(1, '12:00') },
    });
    ctx.matchId = match.id;
    ctx.recSessionId = (await prisma.recommendationSession.create({ data: { userId: player.id } })).id;
  });

  afterAll(async () => {
    try {
      if (createdUserIds.length) {
        await prisma.feedback.deleteMany({
          where: { OR: [{ senderUserId: { in: createdUserIds } }, { recipientUserId: { in: createdUserIds } }] },
        });
        // Facility, Court, Booking, Match, Participant, Rating, Session... xoá theo cascade từ User.
        await prisma.user.deleteMany({ where: { id: { in: createdUserIds } } });
      }
    } finally {
      await prisma.$disconnect();
    }
  });

  // -------------------------------------------------------------------------
  describe('1. Rebuild from clean migrations', () => {
    it('every migration directory is applied, finished and not rolled back', async () => {
      const dir = join(__dirname, '../../prisma/migrations');
      const onDisk = readdirSync(dir).filter((n) => statSync(join(dir, n)).isDirectory()).sort();
      const applied = await prisma.$queryRawUnsafe<
        { migration_name: string; finished_at: Date | null; rolled_back_at: Date | null }[]
      >('SELECT migration_name, finished_at, rolled_back_at FROM "_prisma_migrations" ORDER BY migration_name');

      expect(applied.map((m) => m.migration_name)).toEqual(onDisk);
      expect(applied.every((m) => m.finished_at !== null && m.rolled_back_at === null)).toBe(true);
      expect(onDisk).toContain('20261112090000_smm_44_integrity_constraints');
    });

    it('creates every application table (TimeSlot survives the drop/restore migrations)', async () => {
      const rows = await prisma.$queryRaw<{ table_name: string }[]>`
        SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'`;
      const names = rows.map((r) => r.table_name);
      for (const table of EXPECTED_TABLES) expect(names).toContain(table);
    });

    it('installs every SMM-44 / SMM-36 constraint, and the exclusion constraint is type "x"', async () => {
      const rows = await prisma.$queryRaw<{ conname: string; contype: string }[]>`
        SELECT conname, contype::text AS contype FROM pg_constraint WHERE connamespace = 'public'::regnamespace`;
      const byName = new Map(rows.map((r) => [r.conname, r.contype]));
      for (const name of SMM44_CONSTRAINTS) expect(byName.has(name)).toBe(true);
      expect(byName.get('Booking_no_overlap_excl')).toBe('x');
    });
  });

  // -------------------------------------------------------------------------
  describe('2. CHECK constraints reject invalid rows at database level', () => {
    const cases: Array<[string, () => Promise<unknown>, string]> = [
      ['Booking end == start', () => book(ctx.courtId, at(30, '10:00'), at(30, '10:00')), 'Booking_time_order_check'],
      ['Booking end < start', () => book(ctx.courtId, at(30, '10:00'), at(30, '09:00')), 'Booking_time_order_check'],
      ['Booking negative price', () => prisma.booking.create({ data: { userId: ctx.playerId, courtId: ctx.courtId, startTime: at(30, '10:00'), endTime: at(30, '11:00'), totalPrice: -1 } }), 'Booking_totalPrice_check'],
      ['TimeSlot dayOfWeek 7', () => prisma.timeSlot.create({ data: { courtId: ctx.courtId, dayOfWeek: 7, startTime: '10:00', endTime: '11:00', price: 1 } }), 'TimeSlot_dayOfWeek_check'],
      ['TimeSlot end <= start', () => prisma.timeSlot.create({ data: { courtId: ctx.courtId, dayOfWeek: 1, startTime: '11:00', endTime: '10:00', price: 1 } }), 'TimeSlot_time_order_check'],
      ['TimeSlot negative price', () => prisma.timeSlot.create({ data: { courtId: ctx.courtId, dayOfWeek: 1, startTime: '10:00', endTime: '11:00', price: -5 } }), 'TimeSlot_price_check'],
      ['OperatingHours dayOfWeek 9', () => prisma.operatingHours.create({ data: { facilityId: ctx.facilityId, dayOfWeek: 9, openTime: '06:00', closeTime: '22:00' } }), 'OperatingHours_dayOfWeek_check'],
      ['OperatingHours close <= open', () => prisma.operatingHours.create({ data: { facilityId: ctx.facilityId, dayOfWeek: 3, openTime: '10:00', closeTime: '09:00' } }), 'OperatingHours_time_order_check'],
      ['Availability dayOfWeek 8', () => prisma.availability.create({ data: { userId: ctx.playerId, dayOfWeek: 8, startTime: '18:00', endTime: '20:00' } }), 'Availability_dayOfWeek_check'],
      ['Availability end <= start', () => prisma.availability.create({ data: { userId: ctx.playerId, dayOfWeek: 2, startTime: '20:00', endTime: '18:00' } }), 'Availability_time_order_check'],
      ['PlayingPreference min > max', () => prisma.playingPreference.create({ data: { userId: ctx.playerId, minSkillLevel: 4, maxSkillLevel: 2, maxDistanceKm: 5 } }), 'PlayingPreference_skill_range_check'],
      ['PlayingPreference negative distance', () => prisma.playingPreference.create({ data: { userId: ctx.playerId, minSkillLevel: 1, maxSkillLevel: 3, maxDistanceKm: -1 } }), 'PlayingPreference_maxDistanceKm_check'],
      ['Facility latitude 91', () => prisma.facility.create({ data: { ownerId: ctx.ownerId, name: `${tag}-bad-lat`, address: 'x', latitude: 91, longitude: 108 } }), 'Facility_latitude_check'],
      ['Facility longitude 181', () => prisma.facility.create({ data: { ownerId: ctx.ownerId, name: `${tag}-bad-lon`, address: 'x', latitude: 16, longitude: 181 } }), 'Facility_longitude_check'],
      ['PlayerProfile latitude -91', () => prisma.playerProfile.create({ data: { userId: ctx.noProfileUserId, latitude: -91, longitude: 108 } }), 'PlayerProfile_latitude_check'],
      ['PlayerProfile longitude -181', () => prisma.playerProfile.create({ data: { userId: ctx.noProfileUserId, latitude: 16, longitude: -181 } }), 'PlayerProfile_longitude_check'],
      ['Match end <= start', () => prisma.match.create({ data: { title: `${tag}-m1`, hostId: ctx.ownerId, startTime: at(2, '12:00'), endTime: at(2, '10:00') } }), 'Match_time_order_check'],
      ['Match maxPlayers 1', () => prisma.match.create({ data: { title: `${tag}-m2`, hostId: ctx.ownerId, startTime: at(2, '10:00'), endTime: at(2, '12:00'), maxPlayers: 1 } }), 'Match_maxPlayers_check'],
      ['Match min skill > max skill', () => prisma.match.create({ data: { title: `${tag}-m3`, hostId: ctx.ownerId, startTime: at(2, '10:00'), endTime: at(2, '12:00'), minSkillLevel: 4, maxSkillLevel: 2 } }), 'Match_skill_range_check'],
      ['Feedback rating 6', () => prisma.feedback.create({ data: { matchId: ctx.matchId, senderUserId: ctx.playerId, recipientUserId: ctx.player2Id, rating: 6 } }), 'Feedback_rating_check'],
      ['Feedback rating 0', () => prisma.feedback.create({ data: { matchId: ctx.matchId, senderUserId: ctx.playerId, recipientUserId: ctx.player2Id, rating: 0 } }), 'Feedback_rating_check'],
      ['Feedback to self', () => prisma.feedback.create({ data: { matchId: ctx.matchId, senderUserId: ctx.playerId, recipientUserId: ctx.playerId, rating: 3 } }), 'Feedback_no_self_feedback_check'],
      ['RecommendationResult rank 0', () => prisma.recommendationResult.create({ data: { sessionId: ctx.recSessionId, recommendedUserId: ctx.player2Id, rank: 0, matchScore: 0.5 } }), 'RecommendationResult_rank_check'],
      ['PlayerRating score 6', () => prisma.playerRating.create({ data: { matchId: ctx.matchId, raterId: ctx.playerId, ratedUserId: ctx.player2Id, score: 6 } }), 'PlayerRating_score_check'],
      ['PlayerRating self-rating', () => prisma.playerRating.create({ data: { matchId: ctx.matchId, raterId: ctx.playerId, ratedUserId: ctx.playerId, score: 4 } }), 'PlayerRating_no_self_rating_check'],
    ];

    it.each(cases)('rejects: %s', async (_name, op, constraint) => {
      await expectDbRejects(op, constraint);
    });

    it('accepts boundary values (NULL coordinates, day 0 and 6, rating 1 and 5, adjacent time)', async () => {
      const court = await makeCourt();
      await expect(prisma.timeSlot.create({ data: { courtId: court.id, dayOfWeek: 0, startTime: '06:00', endTime: '07:00', price: 0 } })).resolves.toBeDefined();
      await expect(prisma.timeSlot.create({ data: { courtId: court.id, dayOfWeek: 6, startTime: '06:00', endTime: '07:00', price: 0 } })).resolves.toBeDefined();
      await expect(prisma.facility.create({ data: { ownerId: ctx.ownerId, name: `${tag}-edge`, address: 'x', latitude: 90, longitude: -180 } })).resolves.toBeDefined();
      await expect(prisma.feedback.create({ data: { matchId: ctx.matchId, senderUserId: ctx.playerId, recipientUserId: ctx.player2Id, rating: 1 } })).resolves.toBeDefined();
      await expect(prisma.feedback.create({ data: { matchId: ctx.matchId, senderUserId: ctx.player2Id, recipientUserId: ctx.playerId, rating: 5 } })).resolves.toBeDefined();
    });
  });

  // -------------------------------------------------------------------------
  describe('3. Double-booking prevention (database level, bypassing BookingsService)', () => {
    it.each([
      ['identical range', '18:00', '20:00'],
      ['partial overlap at the end', '19:00', '21:00'],
      ['partial overlap at the start', '17:00', '19:00'],
      ['contained range', '18:30', '19:30'],
      ['covering range', '16:00', '22:00'],
    ])('rejects an overlapping booking on the same court: %s', async (_label, from, to) => {
      const court = await makeCourt();
      const day = nextDay();
      await book(court.id, at(day, '18:00'), at(day, '20:00'));
      await expectDbRejects(() => book(court.id, at(day, from), at(day, to), BookingStatus.CONFIRMED, ctx.player2Id), 'Booking_no_overlap_excl');
      expect(await prisma.booking.count({ where: { courtId: court.id } })).toBe(1);
    });

    it('allows back-to-back bookings (end == next start) and other courts at the same time', async () => {
      const court = await makeCourt();
      const other = await makeCourt();
      const day = nextDay();
      await book(court.id, at(day, '18:00'), at(day, '20:00'));
      await expect(book(court.id, at(day, '20:00'), at(day, '22:00'))).resolves.toBeDefined();
      await expect(book(court.id, at(day, '16:00'), at(day, '18:00'))).resolves.toBeDefined();
      await expect(book(other.id, at(day, '18:00'), at(day, '20:00'))).resolves.toBeDefined();
    });

    it('PENDING blocks like CONFIRMED; CANCELLED never blocks', async () => {
      const court = await makeCourt();
      const day = nextDay();
      await book(court.id, at(day, '18:00'), at(day, '20:00'), BookingStatus.PENDING);
      await expectDbRejects(() => book(court.id, at(day, '18:00'), at(day, '20:00')), 'Booking_no_overlap_excl');

      const day2 = nextDay();
      await book(court.id, at(day2, '18:00'), at(day2, '20:00'), BookingStatus.CANCELLED);
      await expect(book(court.id, at(day2, '18:00'), at(day2, '20:00'), BookingStatus.CONFIRMED)).resolves.toBeDefined();
      await expect(book(court.id, at(day2, '18:00'), at(day2, '20:00'), BookingStatus.CANCELLED, ctx.player2Id)).resolves.toBeDefined();
    });

    it('cancelling releases the slot, but re-activating into an occupied slot is rejected', async () => {
      const court = await makeCourt();
      const day = nextDay();
      const first = await book(court.id, at(day, '18:00'), at(day, '20:00'));
      await prisma.booking.update({ where: { id: first.id }, data: { status: BookingStatus.CANCELLED } });

      const second = await book(court.id, at(day, '18:00'), at(day, '20:00'), BookingStatus.CONFIRMED, ctx.player2Id);
      expect(second.status).toBe(BookingStatus.CONFIRMED);

      await expectDbRejects(
        () => prisma.booking.update({ where: { id: first.id }, data: { status: BookingStatus.CONFIRMED } }),
        'Booking_no_overlap_excl',
      );
      expect((await prisma.booking.findUniqueOrThrow({ where: { id: first.id } })).status).toBe(BookingStatus.CANCELLED);
    });

    it('serializes 8 concurrent inserts for the same slot: exactly one succeeds', async () => {
      const court = await makeCourt();
      const day = nextDay();
      const results = await Promise.allSettled(
        Array.from({ length: 8 }, (_, i) => book(court.id, at(day, '18:00'), at(day, '20:00'), BookingStatus.CONFIRMED, i % 2 ? ctx.player2Id : ctx.playerId)),
      );
      expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
      expect(results.filter((r) => r.status === 'rejected')).toHaveLength(7);
      expect(await prisma.booking.count({ where: { courtId: court.id, status: BookingStatus.CONFIRMED } })).toBe(1);
    });
  });

  // -------------------------------------------------------------------------
  describe('4. Unique keys, foreign keys and cascades', () => {
    it('TimeSlot (courtId, dayOfWeek, startTime) is unique', async () => {
      const court = await makeCourt();
      const data = { courtId: court.id, dayOfWeek: 2, startTime: '18:00', endTime: '19:00', price: 100000 };
      await prisma.timeSlot.create({ data });
      await expect(prisma.timeSlot.create({ data })).rejects.toMatchObject({ code: 'P2002' });
    });

    it('one booking can back only one Match (Match.bookingId is unique)', async () => {
      const court = await makeCourt();
      const day = nextDay();
      const booking = await book(court.id, at(day, '18:00'), at(day, '20:00'));
      await prisma.match.create({ data: { title: `${tag}-b1`, hostId: ctx.playerId, bookingId: booking.id, startTime: booking.startTime, endTime: booking.endTime } });
      await expect(
        prisma.match.create({ data: { title: `${tag}-b2`, hostId: ctx.playerId, bookingId: booking.id, startTime: booking.startTime, endTime: booking.endTime } }),
      ).rejects.toMatchObject({ code: 'P2002' });
    });

    it('deleting a Court cascades to its Bookings; deleting a Booking nulls Match.bookingId', async () => {
      const court = await makeCourt();
      const day = nextDay();
      const booking = await book(court.id, at(day, '18:00'), at(day, '20:00'));
      const match = await prisma.match.create({ data: { title: `${tag}-sn`, hostId: ctx.playerId, bookingId: booking.id, startTime: booking.startTime, endTime: booking.endTime } });

      await prisma.booking.delete({ where: { id: booking.id } });
      expect((await prisma.match.findUniqueOrThrow({ where: { id: match.id } })).bookingId).toBeNull();

      await book(court.id, at(day, '18:00'), at(day, '20:00'));
      await prisma.court.delete({ where: { id: court.id } });
      expect(await prisma.booking.count({ where: { courtId: court.id } })).toBe(0);
    });

    it('Feedback keeps history: deleting a referenced user is RESTRICTed', async () => {
      const sender = await makeUser('fb-sender');
      const recipient = await makeUser('fb-recipient');
      await prisma.feedback.create({ data: { matchId: ctx.matchId, senderUserId: sender.id, recipientUserId: recipient.id, rating: 4 } });
      await expect(prisma.user.delete({ where: { id: recipient.id } })).rejects.toBeDefined();
      expect(await prisma.user.count({ where: { id: recipient.id } })).toBe(1);
    });

    it('rejects a booking that references a missing user or court (FK)', async () => {
      await expect(book(ctx.courtId, at(29, '10:00'), at(29, '11:00'), BookingStatus.CONFIRMED, 2147483000)).rejects.toMatchObject({ code: 'P2003' });
      await expect(book(2147483000, at(29, '10:00'), at(29, '11:00'))).rejects.toMatchObject({ code: 'P2003' });
    });
  });

  // -------------------------------------------------------------------------
  describe('5. Seed data (read-only; needs prisma/seed.ts + prisma/seed-smm44.ts)', () => {
    it('has the three roles', async () => {
      const roles = await prisma.role.findMany();
      expect(roles.map((r) => r.name).sort()).toEqual([RoleName.ADMIN, RoleName.COURT_OWNER, RoleName.PLAYER].sort());
    });

    it('has demo admin, owners and player accounts', async () => {
      const emails = ['admin@smatch.dev', 'owner@smatch.dev', 'owner2@smatch.dev', 'player@smatch.dev'];
      const users = await prisma.user.findMany({ where: { email: { in: emails } }, include: { role: true } });
      expect(users.map((u) => u.email).sort()).toEqual([...emails].sort());
      expect(users.find((u) => u.email === 'owner2@smatch.dev')?.role.name).toBe(RoleName.COURT_OWNER);
    });

    it.each(TOWN.map((t) => [t.owner, t.names] as const))('%s owns exactly its Da Nang facilities (6-4 split)', async (ownerEmail, names) => {
      const facilities = await prisma.facility.findMany({
        where: { owner: { email: ownerEmail }, name: { in: [...ALL_FACILITY_NAMES] } },
        include: { courts: true, operatingHours: true },
      });
      expect(facilities.map((f) => f.name).sort()).toEqual([...names].sort());
      for (const f of facilities) {
        expect(f.courts.length).toBeGreaterThanOrEqual(2);
        expect(f.courts.length).toBeLessThanOrEqual(4);
        expect(f.operatingHours).toHaveLength(7);
        expect(f.latitude).not.toBeNull();
        expect(f.longitude).not.toBeNull();
      }
    });

    it('has 20-40 courts across the 10 facilities, each with a full weekly slot grid', async () => {
      const courts = await prisma.court.findMany({
        where: { facility: { name: { in: ALL_FACILITY_NAMES } } },
        include: { _count: { select: { timeSlots: true } } },
      });
      expect(courts.length).toBeGreaterThanOrEqual(20);
      expect(courts.length).toBeLessThanOrEqual(40);
      expect(courts.every((c) => c._count.timeSlots >= 28)).toBe(true);
    });

    it('has at least 20 players, each with profile, location, 6-axis skill, preference and availability', async () => {
      const players = await prisma.user.findMany({
        where: { email: { startsWith: 'player', endsWith: '@smatch.dev' } },
        include: { playerProfile: { include: { skill: true } }, playingPreference: true, availabilities: true },
      });
      expect(players.length).toBeGreaterThanOrEqual(20);
      for (const p of players) {
        expect(p.playerProfile?.skill).toBeTruthy();
        expect(p.playerProfile?.latitude).not.toBeNull();
        expect(p.playerProfile?.longitude).not.toBeNull();
        expect(p.playingPreference).toBeTruthy();
        expect(p.availabilities.length).toBeGreaterThan(0);
      }
    });

    it('has 30 sample bookings (10 COMPLETED, 15 CONFIRMED, 5 CANCELLED) and 8 sample matches', async () => {
      const grouped = await prisma.booking.groupBy({
        by: ['status'],
        where: { note: { startsWith: 'SMM44-SEED-BOOKING-' } },
        _count: { _all: true },
      });
      const counts = Object.fromEntries(grouped.map((g) => [g.status, g._count._all]));
      expect(counts).toEqual({ COMPLETED: 10, CONFIRMED: 15, CANCELLED: 5 });

      const matches = await prisma.match.findMany({
        where: { title: { startsWith: 'SMM44 Seed Match ' } },
        include: { participants: true },
      });
      expect(matches).toHaveLength(8);
      expect(new Set(matches.map((m) => m.bookingId)).size).toBe(8);
      for (const m of matches) {
        const hosts = m.participants.filter((p) => p.role === 'HOST');
        expect(hosts).toHaveLength(1);
        expect(hosts[0].status).toBe('ACCEPTED');
      }
    });

    it('contains no overlapping active bookings anywhere in the database', async () => {
      const rows = await prisma.$queryRaw<{ n: bigint }[]>`
        SELECT count(*) AS n
        FROM "Booking" a JOIN "Booking" b
          ON a."courtId" = b."courtId" AND a."id" < b."id"
         AND a."status" IN ('PENDING','CONFIRMED') AND b."status" IN ('PENDING','CONFIRMED')
         AND a."startTime" < b."endTime" AND a."endTime" > b."startTime"`;
      expect(Number(rows[0].n)).toBe(0);
    });

    it('keeps owner data isolated: owner revenue sets are disjoint and match the 6-4 split', async () => {
      const rows = await prisma.$queryRaw<{ email: string; facilities: bigint; bookings: bigint }[]>`
        SELECT u."email", count(DISTINCT f."id") AS facilities, count(b."id") AS bookings
        FROM "User" u
        JOIN "Facility" f ON f."ownerId" = u."id" AND f."name" IN (${Prisma.join(ALL_FACILITY_NAMES)})
        LEFT JOIN "Court" c ON c."facilityId" = f."id"
        LEFT JOIN "Booking" b ON b."courtId" = c."id" AND b."note" LIKE 'SMM44-SEED-BOOKING-%'
        WHERE u."email" IN ('owner@smatch.dev', 'owner2@smatch.dev')
        GROUP BY u."email"`;
      const byEmail = Object.fromEntries(rows.map((r) => [r.email, { facilities: Number(r.facilities), bookings: Number(r.bookings) }]));
      expect(byEmail['owner@smatch.dev'].facilities).toBe(6);
      expect(byEmail['owner2@smatch.dev'].facilities).toBe(4);
      expect(byEmail['owner@smatch.dev'].bookings + byEmail['owner2@smatch.dev'].bookings).toBe(30);
    });
  });
});

// ---------------------------------------------------------------------------
// PostGIS — chỉ chạy khi extension có sẵn (image postgis/postgis, xem docker-compose.smm44.yml).
// Kết quả PostGIS (geography, spheroid WGS84) được đối chiếu với haversineKm đang dùng ở
// CandidatesService (cầu hình cầu): lệch tối đa ~0.5%, nên so sánh với dải dung sai 1%.
// ---------------------------------------------------------------------------
livePostgis('SMM-44 PostGIS queries', () => {
  jest.setTimeout(60000);
  let prisma: PrismaClient;

  const CENTER = { lat: 16.061, lon: 108.2165 }; // Hai Chau Badminton
  const RADIUS_M = 5000;
  const BAND = 0.01;

  beforeAll(async () => {
    prisma = new PrismaClient();
    await prisma.$connect();
  });
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('PostGIS extension is installed', async () => {
    const rows = await prisma.$queryRaw<{ v: string }[]>`SELECT postgis_version() AS v`;
    expect(rows[0].v).toMatch(/^\d+\.\d+/);
  });

  it('ST_DWithin + ST_Distance return the nearest facilities in ascending order', async () => {
    const rows = await prisma.$queryRaw<{ name: string; meters: number }[]>`
      SELECT f."name",
             ST_Distance(ST_SetSRID(ST_MakePoint(f."longitude", f."latitude"), 4326)::geography,
                         ST_SetSRID(ST_MakePoint(${CENTER.lon}::float8, ${CENTER.lat}::float8), 4326)::geography) AS meters
      FROM "Facility" f
      WHERE f."latitude" IS NOT NULL AND f."longitude" IS NOT NULL
        AND ST_DWithin(ST_SetSRID(ST_MakePoint(f."longitude", f."latitude"), 4326)::geography,
                       ST_SetSRID(ST_MakePoint(${CENTER.lon}::float8, ${CENTER.lat}::float8), 4326)::geography,
                       ${RADIUS_M}::float8)
      ORDER BY meters ASC`;

    expect(rows.length).toBeGreaterThan(0);
    expect(rows[0].name).toBe('Hai Chau Badminton');
    expect(rows[0].meters).toBeLessThan(1);
    for (let i = 1; i < rows.length; i += 1) expect(rows[i].meters).toBeGreaterThanOrEqual(rows[i - 1].meters);
    expect(rows.every((r) => r.meters <= RADIUS_M)).toBe(true);
    // Cơ sở không có toạ độ (tạo bởi spec phần 1) không bao giờ xuất hiện
    expect(rows.some((r) => r.name.includes('no coordinates'))).toBe(false);
  });

  it('agrees with the Haversine implementation used by CandidatesService (facilities)', async () => {
    const inPostgis = new Set(
      (
        await prisma.$queryRaw<{ id: number }[]>`
          SELECT f."id" FROM "Facility" f
          WHERE f."latitude" IS NOT NULL AND f."longitude" IS NOT NULL
            AND ST_DWithin(ST_SetSRID(ST_MakePoint(f."longitude", f."latitude"), 4326)::geography,
                           ST_SetSRID(ST_MakePoint(${CENTER.lon}::float8, ${CENTER.lat}::float8), 4326)::geography,
                           ${RADIUS_M}::float8)`
      ).map((r) => r.id),
    );
    const all = await prisma.facility.findMany({ where: { latitude: { not: null }, longitude: { not: null } } });
    expect(all.length).toBeGreaterThanOrEqual(10);
    for (const f of all) {
      const meters = haversineKm(CENTER.lat, CENTER.lon, f.latitude as number, f.longitude as number) * 1000;
      if (meters < RADIUS_M * (1 - BAND)) expect(inPostgis.has(f.id)).toBe(true);
      if (meters > RADIUS_M * (1 + BAND)) expect(inPostgis.has(f.id)).toBe(false);
    }
  });

  it('agrees with Haversine for player locations around Da Nang centre', async () => {
    const centre = { lat: 16.047079, lon: 108.20623 };
    const inPostgis = new Set(
      (
        await prisma.$queryRaw<{ userId: number }[]>`
          SELECT p."userId" FROM "PlayerProfile" p
          WHERE p."latitude" IS NOT NULL AND p."longitude" IS NOT NULL
            AND ST_DWithin(ST_SetSRID(ST_MakePoint(p."longitude", p."latitude"), 4326)::geography,
                           ST_SetSRID(ST_MakePoint(${centre.lon}::float8, ${centre.lat}::float8), 4326)::geography,
                           ${RADIUS_M}::float8)`
      ).map((r) => r.userId),
    );
    const all = await prisma.playerProfile.findMany({ where: { latitude: { not: null }, longitude: { not: null } } });
    expect(all.length).toBeGreaterThanOrEqual(20);
    expect(inPostgis.size).toBeGreaterThan(0);
    for (const p of all) {
      const meters = haversineKm(centre.lat, centre.lon, p.latitude as number, p.longitude as number) * 1000;
      if (meters < RADIUS_M * (1 - BAND)) expect(inPostgis.has(p.userId)).toBe(true);
      if (meters > RADIUS_M * (1 + BAND)) expect(inPostgis.has(p.userId)).toBe(false);
    }
  });

  it('ST_Distance is within 1% of Haversine for every facility pair from the centre', async () => {
    const rows = await prisma.$queryRaw<{ id: number; latitude: number; longitude: number; meters: number }[]>`
      SELECT f."id", f."latitude", f."longitude",
             ST_Distance(ST_SetSRID(ST_MakePoint(f."longitude", f."latitude"), 4326)::geography,
                         ST_SetSRID(ST_MakePoint(${CENTER.lon}::float8, ${CENTER.lat}::float8), 4326)::geography) AS meters
      FROM "Facility" f WHERE f."latitude" IS NOT NULL AND f."longitude" IS NOT NULL`;
    for (const r of rows) {
      const expected = haversineKm(CENTER.lat, CENTER.lon, r.latitude, r.longitude) * 1000;
      if (expected > 100) expect(Math.abs(r.meters - expected) / expected).toBeLessThan(BAND);
    }
  });
});
