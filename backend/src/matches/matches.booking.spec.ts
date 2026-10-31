import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { MatchesService } from './matches.service';
import { makeMatchBookingFixture, bookingUniqueError } from '../../test/helpers/matches-booking.fixture';
import { expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';

describe('Match Booking ownership (Prisma mock)', () => {
  let fixture: ReturnType<typeof makeMatchBookingFixture>;
  let service: MatchesService;
  const create = { title: 'Fixture', startTime: '2026-10-20T18:00:00Z', endTime: '2026-10-20T19:00:00Z' };
  const open = { mode: 'DOUBLES', purpose: 'CASUAL', neededPlayers: 2, minSkillLevel: 1, maxSkillLevel: 5 } as const;
  beforeEach(() => {
    fixture = makeMatchBookingFixture();
    service = new MatchesService(fixture.prisma);
  });
  const noWrites = () => {
    expect(fixture.prisma.match.create).not.toHaveBeenCalled();
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
    expect(fixture.prisma.matchParticipant.create).not.toHaveBeenCalled();
    expect(fixture.prisma.matchParticipant.update).not.toHaveBeenCalled();
  };
  function attach(path: string, bookingId: any) {
    if (path === 'create') return service.createMatch(10, { ...create, bookingId });
    if (path === 'patch') return service.updateMatch(11, 10, { bookingId });
    return service.createFromBooking(10, bookingId, open);
  }

  it.each(['create', 'patch', 'open'])('allows a confirmed host-owned Booking via %s', async (path) => {
    const result = await attach(path, 102);
    expectSafeMatchResponse(result);
    expect(fixture.rows.some((row) => row.bookingId === 102 && row.hostId === 10)).toBe(true);
  });

  it.each(['create', 'patch', 'open'])('rejects invalid/foreign/occupied Bookings without writes via %s', async (path) => {
    // Make an occupied booking owned by this host to exercise conflict after ownership.
    fixture.bookings.get(101).userId = 10;
    for (const [id, error] of [
      [999, NotFoundException], [103, ForbiddenException],
      [104, ConflictException], [105, ConflictException], [106, ConflictException],
      [101, ConflictException],
    ] as const) {
      const before = JSON.stringify(fixture.rows);
      await expect(attach(path, id)).rejects.toBeInstanceOf(error);
      expect(JSON.stringify(fixture.rows)).toBe(before);
      noWrites();
    }
  });

  it.each(['create', 'patch', 'open'])('enforces numeric ID bounds and rejects null via %s', async (path) => {
    for (const id of [null, 0, -1, 1.5, 2147483648, Infinity, NaN, '102']) {
      await expect(attach(path, id)).rejects.toBeInstanceOf(BadRequestException);
      noWrites();
    }
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
  });

  it.each(['create', 'patch', 'open'])('accepts ID range boundaries as IDs via %s', async (path) => {
    for (const id of [1, 2147483647]) await expect(attach(path, id)).rejects.toBeInstanceOf(NotFoundException);
    noWrites();
  });

  it('preserves creation without a booking', async () => {
    await service.createMatch(10, create);
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
    expect(fixture.rows.at(-1).bookingId).toBeNull();
  });

  it('preserves PATCH linkage when bookingId is omitted', async () => {
    await service.updateMatch(11, 10, { title: 'Changed' });
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
    expect(fixture.prisma.match.update.mock.calls[0][0].data).not.toHaveProperty('bookingId');
    expect(fixture.privateMatch.bookingId).toBe(100);
  });

  it('validates a repeated current bookingId and returns a no-op without mutation', async () => {
    const before = JSON.stringify(fixture.rows);
    expectSafeMatchResponse(await service.updateMatch(11, 10, { bookingId: 100 }));
    expect(fixture.prisma.booking.findUnique).toHaveBeenCalled();
    expect(JSON.stringify(fixture.rows)).toBe(before);
    noWrites();
  });

  it.each(['owner', 'status'])('rejects an invalid current Booking %s even for a repeated ID', async (change) => {
    if (change === 'owner') fixture.bookings.get(100).userId = 20;
    else fixture.bookings.get(100).status = 'CANCELLED';
    await expect(service.updateMatch(11, 10, { bookingId: 100 })).rejects.toBeInstanceOf(change === 'owner' ? ForbiddenException : ConflictException);
    noWrites();
  });

  it('does not trust injected hostId/userId/relations in internal calls', async () => {
    await expect(service.updateMatch(11, 20, { bookingId: 103, hostId: 20 } as any)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.updateMatch(11, 10, { bookingId: 103, hostId: 20 } as any)).rejects.toBeInstanceOf(ForbiddenException);
    noWrites();
    await service.updateMatch(11, 10, { title: 'Changed', hostId: 20, userId: 20, booking: { connect: { id: 103 } } } as any);
    expect(fixture.privateMatch.hostId).toBe(10);
    expect(fixture.privateMatch.bookingId).toBe(100);
    const data = fixture.prisma.match.update.mock.calls[0][0].data;
    expect(Object.keys(data)).toEqual(['title']);
  });

  it('uses caller identity rather than injected hostId when creating', async () => {
    await expect(service.createMatch(10, { ...create, bookingId: 103, hostId: 20 } as any)).rejects.toBeInstanceOf(ForbiddenException);
    noWrites();
  });

  it('checks Match existence and host permission before reading another Booking', async () => {
    await expect(service.updateMatch(999, 10, { bookingId: 102 })).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.updateMatch(11, 80, { bookingId: 108 })).rejects.toBeInstanceOf(ForbiddenException);
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('maps a race P2002 to 409 for %s', async (path) => {
    const write = path === 'patch' ? fixture.prisma.match.update : fixture.prisma.match.create;
    write.mockRejectedValueOnce(bookingUniqueError('Match_bookingId_key'));
    const before = JSON.stringify(fixture.rows);
    await expect(attach(path, 102)).rejects.toBeInstanceOf(ConflictException);
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });

  it.each(['create', 'patch', 'open'])('locks and validates Booking with the transaction client for %s', async (path) => {
    const events: string[] = [];
    const root = fixture.prisma;
    const readBooking = root.booking.findUnique;
    const tx = {
      ...root,
      $queryRaw: jest.fn(async (sql, id) => {
        if (sql.join('?').includes('"Match"')) {
          expect(path).toBe('patch');
          expect(sql.join('?')).toContain('WHERE id = ? FOR UPDATE');
          expect(id).toBe(11);
          events.push('match-lock');
          return [];
        }
        expect(sql.join('?')).toContain('WHERE id = ? FOR SHARE');
        expect(id).toBe(102);
        events.push('lock');
        return [];
      }),
      booking: { findUnique: jest.fn(async (args) => { events.push('read'); return readBooking(args); }) },
    };
    const write = path === 'patch' ? tx.match.update : tx.match.create;
    const implementation = write.getMockImplementation();
    write.mockImplementation(async (args: any) => { events.push('write'); return implementation(args); });
    root.booking = { findUnique: jest.fn(() => { throw new Error('Must use transaction client'); }) };
    root.$queryRaw = jest.fn(() => { throw new Error('Must use transaction client'); });
    root.$transaction.mockImplementation(async (callback: (client: typeof tx) => Promise<unknown>) => callback(tx));

    await attach(path, 102);
    expect(root.$transaction).toHaveBeenCalledTimes(1);
    expect(root.booking.findUnique).not.toHaveBeenCalled();
    expect(root.$queryRaw).not.toHaveBeenCalled();
    expect(events).toEqual(path === 'patch' ? ['match-lock', 'lock', 'read', 'write'] : ['lock', 'read', 'write']);
  });

  it.each(['create', 'patch', 'open'])('maps transaction-level booking unique failure to 409 for %s', async (path) => {
    fixture.prisma.$transaction.mockRejectedValueOnce(bookingUniqueError());
    await expect(attach(path, 102)).rejects.toBeInstanceOf(ConflictException);
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('maps a database deadlock/write conflict to 409 without retry for %s', async (path) => {
    fixture.prisma.$transaction.mockRejectedValueOnce(new Prisma.PrismaClientKnownRequestError('PRIVATE_PRISMA_DETAILS', {
      code: 'P2034', clientVersion: '6.19.3',
    }));
    await expect(attach(path, 102)).rejects.toBeInstanceOf(ConflictException);
    expect(fixture.prisma.$transaction).toHaveBeenCalledTimes(1);
    noWrites();
  });

  it.each(['create', 'patch', 'open'])('does not misreport unrelated P2002 or leak Prisma details via %s', async (path) => {
    const write = path === 'patch' ? fixture.prisma.match.update : fixture.prisma.match.create;
    write.mockRejectedValueOnce(bookingUniqueError(['anotherField']));
    await expect(attach(path, 102)).rejects.toMatchObject({ status: 500, message: 'Không thể lưu trận đấu' });
  });

  it.each(['create', 'patch', 'mixed'])('allows only one competing Booking attachment: %s', async (kind) => {
    if (kind === 'patch') {
      fixture.openMatch.hostId = 10;
      fixture.bookings.get(101).userId = 10;
    }
    const count = fixture.rows.length;
    const first = kind === 'patch'
      ? service.updateMatch(11, 10, { bookingId: 102 })
      : service.createMatch(10, { ...create, bookingId: 102 });
    const second = kind === 'patch'
      ? service.updateMatch(12, 10, { bookingId: 102 })
      : kind === 'mixed' ? service.createFromBooking(10, 102, open)
      : service.createMatch(10, { ...create, bookingId: 102 });
    const results = await Promise.allSettled([first, second]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const failure = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    expect(failure.reason).toBeInstanceOf(ConflictException);
    expect(fixture.rows.filter((row) => row.bookingId === 102)).toHaveLength(1);
    expect(fixture.rows).toHaveLength(count + (kind === 'patch' ? 0 : 1));
  });
});
