// In-memory fixtures only. This mock applies select/where rather than returning
// pre-sanitized responses, so HTTP tests exercise the service projections.
export function matchesWhere(row: any, where: any = {}): boolean {
  return Object.entries(where).every(([key, value]: [string, any]) => {
    if (value === undefined) return true;
    if (key === 'AND') return (Array.isArray(value) ? value : [value]).every((w) => matchesWhere(row, w));
    if (key === 'OR') return value.some((w: any) => matchesWhere(row, w));
    if (key === 'participants') return row.participants.some((p: any) => matchesWhere(p, value.some));
    if (value && typeof value === 'object' && 'in' in value) return value.in.includes(row[key]);
    return row[key] === value;
  });
}

export function projectMatch(row: any, select?: any): any {
  if (row === null || row === undefined) return null;
  if (!select) return { ...row };
  return Object.fromEntries(Object.entries(select).map(([key, value]: [string, any]) => {
    if (value === true) return [key, row[key]];
    if (key === '_count') {
      return [key, { participants: row.participants.filter((p: any) => matchesWhere(p, value.select.participants.where)).length }];
    }
    const source = row[key];
    if (Array.isArray(source)) {
      return [key, source.filter((p) => matchesWhere(p, value.where)).map((p) => projectMatch(p, value.select))];
    }
    return [key, projectMatch(source, value.select)];
  }));
}

export function makeMatchSecurityFixture() {
  const date = new Date('2026-10-20T18:00:00Z');
  const statuses = ['ACCEPTED', 'ACCEPTED', 'INVITED', 'REQUESTED', 'REJECTED', 'CANCELLED'];
  const ids = [10, 30, 40, 50, 60, 70];
  const privateMatch = {
    id: 11, title: 'Private fixture', description: 'Match description', privacy: 'PRIVATE', status: 'OPEN',
    mode: 'DOUBLES', purpose: 'CASUAL', minSkillLevel: 1, maxSkillLevel: 5,
    hostId: 10, host: { id: 10, fullName: 'Fixture Host', email: 'host@example.test', phone: 'not-public' },
    bookingId: 100, startTime: date, endTime: new Date(date.getTime() + 3600000), location: 'Fixture Court',
    maxPlayers: 4, feePerPlayer: 50000, createdAt: date, updatedAt: date,
    booking: {
      id: 100, userId: 10, note: 'PRIVATE_BOOKING_NOTE', status: 'CONFIRMED',
      startTime: date, endTime: new Date(date.getTime() + 3600000), totalPrice: 200000,
      createdAt: date, updatedAt: date,
      court: { id: 5, name: 'Fixture Court', courtType: 'INDOOR', facilityId: 6, createdAt: date,
        facility: { id: 6, ownerId: 20, name: 'Fixture Facility', address: 'Fixture address', latitude: 1, longitude: 2, contactPhone: 'not-public', createdAt: date } },
    },
    participants: ids.map((userId, index) => ({
      id: index + 1, userId, matchId: 11, role: index === 0 ? 'HOST' : 'MEMBER', status: statuses[index],
      createdAt: date, updatedAt: date,
      user: { id: userId, fullName: 'Fixture Member', email: `member${userId}@example.test`, phone: 'not-public' },
    })),
  };
  const openMatch = {
    ...privateMatch, id: 12, title: 'Open fixture', privacy: 'OPEN',
    participants: privateMatch.participants.map((p) => ({ ...p, id: p.id + 100, matchId: 12 })),
  };
  const rows: any[] = [privateMatch, openMatch];
  const find = ({ where, select, include }: any) => {
    const row = rows.find((entry) => matchesWhere(entry, where));
    if (!row) return null;
    if (select) return projectMatch(row, select);
    if (include?.participants?.where) {
      return { ...row, participants: row.participants.filter((p: any) => matchesWhere(p, include.participants.where)) };
    }
    return { ...row };
  };
  const prisma: any = {
    $queryRaw: jest.fn(async () => []),
    match: {
      findUnique: jest.fn(async (args) => find(args)),
      findFirst: jest.fn(async (args) => find(args)),
      findMany: jest.fn(async ({ where, select }) => rows.filter((row) => matchesWhere(row, where)).map((row) => projectMatch(row, select))),
      update: jest.fn(async ({ where, data, select }) => {
        const row = rows.find((entry) => matchesWhere(entry, where));
        Object.assign(row, data);
        return projectMatch(row, select);
      }),
      create: jest.fn(async ({ data, select }) => projectMatch({ ...privateMatch, ...data, participants: privateMatch.participants }, select)),
    },
    booking: { findUnique: jest.fn(async () => ({ ...privateMatch.booking, court: privateMatch.booking.court, match: null })) },
    matchParticipant: {
      findUnique: jest.fn(async ({ where }) => {
        const pair = where.matchId_userId;
        const match = rows.find((row) => row.id === pair.matchId);
        const participant = match?.participants.find((p: any) => p.userId === pair.userId);
        return participant ? { ...participant, match: { ...match, participants: match.participants.filter((p: any) => p.status === 'ACCEPTED') } } : null;
      }),
      update: jest.fn(async ({ where, data, select }) => {
        const participant = rows.flatMap((row) => row.participants).find((p) => p.id === where.id)!;
        Object.assign(participant, data);
        return projectMatch(participant, select);
      }),
      create: jest.fn(async ({ data, select }) => projectMatch({
        id: 99, createdAt: date, updatedAt: date,
        user: { email: 'not-public@example.test' }, ...data,
      }, select)),
    },
    refreshSession: { findUnique: jest.fn() },
  };
  prisma.$transaction = jest.fn(async (callback) => callback(prisma));
  return { prisma, rows, privateMatch, openMatch };
}

export function expectSafeMatchResponse(value: any) {
  const forbidden = new Set(['email', 'phone', 'password', 'passwordHash', 'refreshTokenHash', 'note', 'createdAt', 'updatedAt', '_count', 'ownerId', 'contactPhone']);
  function visit(entry: any) {
    if (!entry || typeof entry !== 'object' || entry instanceof Date) return;
    for (const [key, child] of Object.entries(entry)) {
      expect(forbidden.has(key)).toBe(false);
      visit(child);
    }
  }
  visit(value);
  if (value.booking) {
    expect(value.booking).not.toHaveProperty('userId');
    expect(value.booking).not.toHaveProperty('id');
  }
}
