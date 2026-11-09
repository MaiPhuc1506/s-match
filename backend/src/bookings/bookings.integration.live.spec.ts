import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomBytes, randomUUID } from 'node:crypto';
import request from 'supertest';
import { AppModule } from '../app.module';
import { AUTH_JWT_CONFIG } from '../auth/jwt.config';
import { PrismaService } from '../prisma/prisma.service';
import { RoleName } from '@prisma/client';
import { vietnamDay, vietnamTime } from './booking-time';

// Explicit opt-in: writes only uniquely identified test accounts/facilities,
// then removes those records. Does not migrate, reset, seed or wipe the database.
const live = process.env.RUN_BOOKING_LIVE === '1' ? describe : describe.skip;
live('P0.1 Booking integration (real PostgreSQL + auth + row locks)', () => {
  let app: INestApplication;
  let db: PrismaService;
  const users: number[] = [];
  const tokens: string[] = [];
  let facilityId: number;
  let courtId: number;
  let date: string;
  let first: any;
  let second: any;
  let winner = 0;
  let bookingId: number;
  const owner = 2, otherOwner = 3;

  beforeAll(async () => {
    const module = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: randomBytes(32).toString('hex'), refreshSecret: randomBytes(32).toString('hex'),
        issuer: 'booking-p01-test', accessAudience: 's-match-api', refreshAudience: 's-match-refresh',
      }).compile();
    db = module.get(PrismaService);
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
    for (let i = 0; i < 4; i++) {
      const email = `booking-p01-${randomUUID()}@example.test`;
      const password = randomBytes(18).toString('hex');
      const registered = await request(app.getHttpServer()).post('/auth/register')
        .send({ email, password, fullName: `Booking integration ${i}` }).expect(201);
      const id = registered.body.data.id;
      users.push(id);
      if (i >= owner) {
        const role = await db.role.upsert({ where: { name: RoleName.COURT_OWNER }, update: {}, create: { name: RoleName.COURT_OWNER } });
        await db.user.update({ where: { id }, data: { roleId: role.id } });
      }
      const login = await request(app.getHttpServer()).post('/auth/login').send({ email, password }).expect(201);
      tokens.push(login.body.accessToken);
    }
    const f = await db.facility.create({ data: {
      ownerId: users[owner], name: 'P0.1 integration facility', address: 'Test-only facility',
      latitude: 16.06, longitude: 108.21,
      courts: { create: [{ name: 'Unselected court' }, { name: 'Selected court' }] },
    }, include: { courts: { orderBy: { id: 'asc' } } } });
    facilityId = f.id;
    courtId = f.courts[1].id;
    date = vietnamTime(new Date(Date.now() + 3 * 86400000)).date;
    const dayOfWeek = vietnamDay(date).dayOfWeek;
    await db.operatingHours.create({ data: { facilityId, dayOfWeek, openTime: '06:00', closeTime: '22:00' } });
    await db.timeSlot.createMany({ data: [
      { courtId, dayOfWeek, startTime: '06:00', endTime: '07:00', price: 125000 },
      { courtId, dayOfWeek, startTime: '07:00', endTime: '08:00', price: 175000 },
      { courtId, dayOfWeek, startTime: '08:00', endTime: '09:00', price: 0, isActive: false },
    ] });
    first = { facilityId, courtId, startTime: `${date}T06:00:00+07:00`, endTime: `${date}T07:00:00+07:00` };
    second = { ...first, startTime: `${date}T07:00:00+07:00`, endTime: `${date}T08:00:00+07:00` };
  }, 30000);

  afterAll(async () => {
    try {
      if (db && users.length) await db.user.deleteMany({ where: { id: { in: users } } });
    } finally {
      await app?.close();
      await db?.$disconnect();
    }
  });

  function api(method: 'get' | 'post' | 'patch', path: string, account = 0) {
    return request(app.getHttpServer())[method](path).auth(tokens[account], { type: 'bearer' });
  }
  const availability = () => `/facilities/${facilityId}/courts/${courtId}/time-slots/availability?date=${date}`;

  it('keeps map facility identity, selected non-first court and configured prices', async () => {
    const map = await request(app.getHttpServer()).get('/facilities').expect(200);
    expect(map.body.find((f: any) => f.id === facilityId).courts.some((c: any) => c.id === courtId)).toBe(true);
    const detail = await request(app.getHttpServer()).get(`/facilities/${facilityId}`).expect(200);
    expect(detail.body.courts.some((c: any) => c.id === courtId)).toBe(true);
    const slots = await request(app.getHttpServer()).get(availability()).expect(200);
    expect(slots.body.map((s: any) => [s.price, s.isBooked])).toEqual([[125000, false], [175000, false]]);
    await api('post', '/bookings').send({ ...first, facilityId: facilityId + 1 }).expect(400);
    await api('post', '/bookings').send({ ...first, courtId: -1 }).expect(400);
    await api('post', '/bookings').send({ ...first, startTime: `${date}T06:00:00` }).expect(400);
    await api('post', '/bookings').send({ ...first, totalPrice: 1 }).expect(400);
    expect(await db.booking.count({ where: { courtId } })).toBe(0);
  });

  it('serializes concurrent requests: one CONFIRMED row, one 409, correct persisted price', async () => {
    const results = await Promise.all([api('post', '/bookings', 0).send(first), api('post', '/bookings', 1).send(first)]);
    expect(results.map((r) => r.status).sort()).toEqual([201, 409]);
    winner = results[0].status === 201 ? 0 : 1;
    const b = results[winner].body;
    bookingId = b.id;
    expect(b).toMatchObject({ courtId, userId: users[winner], totalPrice: 125000, status: 'CONFIRMED' });
    expect(b.court.facility.id).toBe(facilityId);
    expect(await db.booking.count({ where: { courtId } })).toBe(1);
    const stored = await db.booking.findUniqueOrThrow({ where: { id: bookingId } });
    expect(stored.totalPrice).toBe(125000);
    const slots = await request(app.getHttpServer()).get(availability()).expect(200);
    expect(slots.body.map((s: any) => s.isBooked)).toEqual([true, false]);
  });

  it('reflects bookings in Player history, Owner feed and real Owner analytics only within scope', async () => {
    const history = await api('get', '/bookings/my', winner).expect(200);
    expect(history.body.some((b: any) => b.id === bookingId && b.courtId === courtId)).toBe(true);
    const other = await api('get', '/bookings/my', 1 - winner).expect(200);
    expect(other.body.some((b: any) => b.id === bookingId)).toBe(false);
    const owned = await api('get', `/bookings/owner?facilityId=${facilityId}`, owner).expect(200);
    expect(owned.body.map((b: any) => b.id)).toContain(bookingId);
    await api('get', `/bookings/owner?facilityId=${facilityId}`, otherOwner).expect(403);
    await api('get', '/bookings/owner', winner).expect(403);
    const isolated = await api('get', '/bookings/owner', otherOwner).expect(200);
    expect(isolated.body).toEqual([]);
    const overview = await api('get', `/analytics/revenue/overview?facilityId=${facilityId}&from=${date}&to=${date}`, owner).expect(200);
    expect(overview.body.totalBookings).toBe(1);
    await api('get', `/bookings/${bookingId}`, otherOwner).expect(403);
  });

  it('rejects overlaps/disabled slots, permits adjacent boundary and cancellation releases availability', async () => {
    // Equivalent Z instants cross UTC midnight but remain in one Vietnam day.
    await api('post', '/bookings', 1 - winner).send({ ...first,
      startTime: new Date(first.startTime).toISOString(), endTime: new Date(first.endTime).toISOString(),
    }).expect(409);
    await api('post', '/bookings').send({ ...first, startTime: `${date}T06:30:00+07:00`, endTime: `${date}T07:30:00+07:00` }).expect(409);
    const adjacent = await api('post', '/bookings').send(second).expect(201);
    expect(adjacent.body.totalPrice).toBe(175000);
    await api('post', '/bookings').send({ ...first, startTime: `${date}T08:00:00+07:00`, endTime: `${date}T09:00:00+07:00` }).expect(400);
    await api('patch', `/bookings/${bookingId}/cancel`, winner).expect(200);
    const slots = await request(app.getHttpServer()).get(availability()).expect(200);
    expect(slots.body.map((s: any) => s.isBooked)).toEqual([false, true]);
    await api('post', '/bookings', 1 - winner).send(first).expect(201);
  });
});
