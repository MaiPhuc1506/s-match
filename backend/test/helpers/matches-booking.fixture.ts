import { Prisma } from '@prisma/client';
import { makeMatchSecurityFixture, matchesWhere, projectMatch } from './matches-security.fixture';

export function bookingUniqueError(target: string | string[] = ['bookingId']) {
  return new Prisma.PrismaClientKnownRequestError('PRIVATE_PRISMA_DETAILS', {
    code: 'P2002', clientVersion: '6.19.3', meta: { modelName: 'Match', target },
  });
}

// In-memory persistence and uniqueness checks; never instantiates PrismaClient.
export function makeMatchBookingFixture() {
  const fixture = makeMatchSecurityFixture();
  const { prisma, rows, privateMatch, openMatch } = fixture;
  openMatch.hostId = 20;
  openMatch.bookingId = 101;
  openMatch.participants = structuredClone(openMatch.participants);
  const bookings = new Map<number, any>();
  for (const [id, userId, status] of [
    [100, 10, 'CONFIRMED'], [101, 20, 'CONFIRMED'],
    [102, 10, 'CONFIRMED'], [103, 20, 'CONFIRMED'],
    [104, 10, 'PENDING'], [105, 10, 'CANCELLED'], [106, 10, 'COMPLETED'],
    [108, 80, 'CONFIRMED'],
  ] as const) {
    bookings.set(id, { ...structuredClone(privateMatch.booking), id, userId, status });
  }
  openMatch.booking = bookings.get(101);

  prisma.booking.findUnique = jest.fn(async ({ where, select }) => {
    const row = bookings.get(where.id);
    return row ? projectMatch({ ...row, match: rows.find((match) => match.bookingId === row.id) ?? null }, select) : null;
  });
  prisma.match.create = jest.fn(async ({ data, select }) => {
    if (data.bookingId != null && rows.some((row) => row.bookingId === data.bookingId)) throw bookingUniqueError();
    const id = Math.max(...rows.map((row) => row.id)) + 1;
    const row = {
      ...structuredClone(privateMatch), ...data, id,
      bookingId: data.bookingId ?? null,
      booking: bookings.get(data.bookingId) ?? null,
      host: { id: data.hostId, fullName: 'Fixture Host' },
      participants: [{ id: id * 10, ...data.participants.create, user: { id: data.hostId, fullName: 'Fixture Host' } }],
    };
    rows.push(row);
    return projectMatch(row, select);
  });
  prisma.match.update = jest.fn(async ({ where, data, select }) => {
    const row = rows.find((entry) => matchesWhere(entry, where));
    if (!row) throw new Prisma.PrismaClientKnownRequestError('PRIVATE_PRISMA_DETAILS', { code: 'P2025', clientVersion: '6.19.3' });
    if (data.bookingId != null && rows.some((other) => other.id !== row.id && other.bookingId === data.bookingId)) throw bookingUniqueError();
    for (const [key, value] of Object.entries(data)) {
      if (value !== undefined) row[key] = value;
    }
    if (data.bookingId !== undefined) row.booking = bookings.get(data.bookingId) ?? null;
    return projectMatch(row, select);
  });
  prisma.$transaction = jest.fn(async (callback) => callback(prisma));
  return { ...fixture, bookings };
}
