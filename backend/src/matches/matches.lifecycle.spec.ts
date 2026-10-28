import { BadRequestException, ConflictException, ForbiddenException, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { MatchState, Prisma } from '@prisma/client';
import { MatchesService } from './matches.service';
import { makeMatchLifecycleFixture } from '../../test/helpers/matches-lifecycle.fixture';
import { expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';

describe('SMM-34 Complete Match and lifecycle (transaction simulator only)', () => {
  const now = new Date('2026-10-27T12:00:00Z');
  let fixture: ReturnType<typeof makeMatchLifecycleFixture>;
  let service: MatchesService;
  beforeEach(() => {
    jest.useFakeTimers({ doNotFake: ['nextTick', 'setImmediate'] });
    jest.setSystemTime(now);
    fixture = makeMatchLifecycleFixture();
    service = new MatchesService(fixture.prisma);
  });
  afterEach(() => jest.useRealTimers());
  function noWrites() {
    for (const model of [fixture.prisma.match, fixture.prisma.matchParticipant]) {
      expect(model.create).not.toHaveBeenCalled();
      expect(model.update).not.toHaveBeenCalled();
      if (model.updateMany) expect(model.updateMany).not.toHaveBeenCalled();
    }
  }
  const actions = ['cancel', 'patch-title', 'patch-time', 'patch-booking', 'patch-empty', 'leave',
    'invite-new', 'invite-existing', 'join-new', 'join-existing', 'accept', 'reject-invite',
    'approve', 'reject-request', 'approve-alias', 'reject-alias'] as const;
  function mutate(action: typeof actions[number]) {
    if (action === 'cancel') return service.cancelMatch(11, 10);
    if (action === 'patch-title') return service.updateMatch(11, 10, { title: 'Changed' });
    if (action === 'patch-time') return service.updateMatch(11, 10, { endTime: '2026-10-28T12:00:00Z' });
    if (action === 'patch-booking') return service.updateMatch(11, 10, { bookingId: 102 });
    if (action === 'patch-empty') return service.updateMatch(11, 10, {});
    if (action === 'leave') return service.leave(30, 11);
    if (action.startsWith('invite-')) return service.inviteUser(11, 10, action.endsWith('new') ? 90 : 60);
    if (action.startsWith('join-')) return service.requestToJoin(11, action.endsWith('new') ? 90 : 60);
    if (action === 'accept') return service.acceptInvitation(11, 40);
    if (action === 'reject-invite') return service.rejectInvitation(11, 40);
    if (action === 'approve') return service.hostApproveRequest(11, 10, 50);
    if (action === 'reject-request') return service.hostRejectRequest(11, 10, 50);
    return service.respondToRequest(10, 11, 4, action === 'approve-alias');
  }

  it.each([MatchState.OPEN, MatchState.FULL, MatchState.IN_PROGRESS])('completes %s with a host-safe projection and no Booking/roster changes', async (status) => {
    fixture.privateMatch.status = status;
    const roster = structuredClone(fixture.privateMatch.participants);
    const bookings = structuredClone([...fixture.bookings]);
    const result = await service.completeMatch(11, 10);
    expect(result.status).toBe(MatchState.COMPLETED);
    expectSafeMatchResponse(result);
    expect(fixture.privateMatch.participants).toEqual(roster);
    expect([...fixture.bookings]).toEqual(bookings);
    expect(fixture.prisma.match.updateMany).toHaveBeenCalledWith({
      where: { id: 11, hostId: 10, status: { in: ['OPEN', 'FULL', 'IN_PROGRESS'] }, endTime: { lte: now } },
      data: { status: 'COMPLETED' },
    });
    expect(fixture.events).toEqual(['begin', 'lock-match', 'commit']);
    const [sql, id] = fixture.prisma.$queryRaw.mock.calls[0];
    expect(sql.join('?')).toBe('SELECT id FROM "Match" WHERE id = ? FOR UPDATE');
    expect(id).toBe(11);
    expect(fixture.prisma.$transaction.mock.calls[0][1]).toEqual({ isolationLevel: 'ReadCommitted' });
  });
  it('permits completion exactly at endTime, but rejects one millisecond early', async () => {
    fixture.privateMatch.endTime = new Date(now.getTime() + 1);
    await expect(service.completeMatch(11, 10)).rejects.toBeInstanceOf(ConflictException);
    noWrites();
    fixture.privateMatch.endTime = now;
    await expect(service.completeMatch(11, 10)).resolves.toMatchObject({ status: 'COMPLETED' });
  });
  it.each([30, 80, 90])('rejects non-host %s before mutation', async (id) => {
    await expect(service.completeMatch(11, id)).rejects.toBeInstanceOf(ForbiddenException);
    noWrites();
  });
  it.each([MatchState.CANCELLED, MatchState.COMPLETED])('rejects completion of %s', async (status) => {
    fixture.privateMatch.status = status;
    await expect(service.completeMatch(11, 10)).rejects.toBeInstanceOf(ConflictException);
    noWrites();
  });
  it('reports missing Match without mutation', async () => {
    await expect(service.completeMatch(999, 10)).rejects.toBeInstanceOf(NotFoundException);
    noWrites();
  });
  it.each([0, -1, 1.5, 2147483648, NaN])('validates Match ID %s before a transaction', async (id) => {
    await expect(service.completeMatch(id, 10)).rejects.toBeInstanceOf(BadRequestException);
    expect(fixture.prisma.$transaction).not.toHaveBeenCalled();
  });
  it('returns 409 when the write predicate no longer matches', async () => {
    fixture.prisma.match.updateMany.mockResolvedValueOnce({ count: 0 });
    await expect(service.completeMatch(11, 10)).rejects.toBeInstanceOf(ConflictException);
    expect(fixture.privateMatch.status).toBe('OPEN');
    expect(fixture.events.at(-1)).toBe('rollback');
  });
  it('uses the transaction client for the lock, participant update, recalculation and completion', async () => {
    const root = fixture.prisma;
    const db = { ...root, match: { ...root.match }, matchParticipant: { ...root.matchParticipant } };
    const wrongClient = jest.fn(() => { throw new Error('Must use the locked transaction client'); });
    root.match = { findUnique: wrongClient, update: wrongClient, updateMany: wrongClient };
    root.matchParticipant = { findUnique: wrongClient, update: wrongClient, create: wrongClient };
    root.$queryRaw = wrongClient;
    root.$transaction.mockImplementation(async (action: (tx: any) => Promise<any>) => action(db));
    await service.acceptInvitation(11, 40);
    await service.completeMatch(11, 10);
    expect(wrongClient).not.toHaveBeenCalled();
    expect(db.$queryRaw).toHaveBeenCalledTimes(2);
    expect(db.matchParticipant.update).toHaveBeenCalledTimes(1);
    expect(db.match.updateMany).toHaveBeenCalledTimes(2);
    expect(fixture.privateMatch.status).toBe('COMPLETED');
  });
  it('allows only one of two concurrent complete requests', async () => {
    const results = await Promise.allSettled([service.completeMatch(11, 10), service.completeMatch(11, 10)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    const rejected = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    expect(rejected.reason).toBeInstanceOf(ConflictException);
    expect(fixture.prisma.match.updateMany).toHaveBeenCalledTimes(1);
    expect(fixture.privateMatch.status).toBe('COMPLETED');
  });
  it.each(actions)('blocks %s on a completed Match without mutation', async (action) => {
    fixture.privateMatch.status = MatchState.COMPLETED;
    const before = structuredClone(fixture.rows);
    await expect(mutate(action)).rejects.toBeInstanceOf(ConflictException);
    noWrites();
    expect(fixture.rows).toEqual(before);
  });
  it.each(actions)('serializes %s behind a concurrent completion', async (action) => {
    const [complete, oldRequest] = await Promise.allSettled([service.completeMatch(11, 10), mutate(action)]);
    expect(complete.status).toBe('fulfilled');
    expect(oldRequest.status).toBe('rejected');
    expect((oldRequest as PromiseRejectedResult).reason).toBeInstanceOf(ConflictException);
    expect(fixture.privateMatch.status).toBe('COMPLETED');
    expect(fixture.prisma.matchParticipant.update).not.toHaveBeenCalled();
    expect(fixture.prisma.matchParticipant.create).not.toHaveBeenCalled();
  });
  it('sees a time edit committed before completion instead of using stale endTime', async () => {
    const results = await Promise.allSettled([
      service.updateMatch(11, 10, { endTime: '2026-10-28T12:00:00Z' }), service.completeMatch(11, 10),
    ]);
    expect(results[0].status).toBe('fulfilled');
    expect((results[1] as PromiseRejectedResult).reason).toBeInstanceOf(ConflictException);
    expect(fixture.privateMatch.status).toBe('OPEN');
  });
  it.each(actions.filter((action) => action !== 'patch-time'))('retains valid %s committed before completion', async (action) => {
    fixture.privateMatch.privacy = 'OPEN';
    let entered!: () => void;
    const locked = new Promise<void>((resolve) => { entered = resolve; });
    const lock = fixture.prisma.$queryRaw.getMockImplementation();
    fixture.prisma.$queryRaw.mockImplementationOnce(async (...args: any[]) => {
      const result = await lock(...args);
      entered();
      return result;
    });
    // Aliases perform a read before delegation; wait for the actual mutation lock.
    const oldRequestPromise = mutate(action);
    await locked;
    const [oldRequest, completion] = await Promise.allSettled([oldRequestPromise, service.completeMatch(11, 10)]);
    expect(oldRequest.status).toBe('fulfilled');
    if (action === 'cancel') {
      expect((completion as PromiseRejectedResult).reason).toBeInstanceOf(ConflictException);
      expect(fixture.privateMatch.status).toBe('CANCELLED');
    } else {
      expect(completion.status).toBe('fulfilled');
      expect(fixture.privateMatch.status).toBe('COMPLETED');
    }
  });
  it('does not let stale OPEN/FULL recalculation overwrite COMPLETED at write time', async () => {
    const original = fixture.prisma.match.findUnique.getMockImplementation();
    fixture.prisma.match.findUnique.mockImplementationOnce(async (args: any) => {
      const stale = await original(args);
      fixture.privateMatch.status = 'COMPLETED';
      return stale;
    });
    await (service as any).checkAndUpdateMatchFullState(11, fixture.prisma);
    expect(fixture.privateMatch.status).toBe('COMPLETED');
    expect(fixture.prisma.match.updateMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { id: 11, status: { in: ['OPEN', 'FULL'] } },
    }));
  });
  it('rolls back completion if reading the response fails', async () => {
    const original = fixture.prisma.match.findUnique.getMockImplementation();
    fixture.prisma.match.findUnique.mockImplementationOnce(original).mockRejectedValueOnce(new Error('response failure'));
    await expect(service.completeMatch(11, 10)).rejects.toThrow('response failure');
    expect(fixture.privateMatch.status).toBe('OPEN');
    expect(fixture.events.at(-1)).toBe('rollback');
  });
  it.each(['P2034', 'P2024'])('sanitizes Prisma %s without retry', async (code) => {
    fixture.prisma.$queryRaw.mockRejectedValueOnce(new Prisma.PrismaClientKnownRequestError('PRIVATE_DATABASE_DETAILS', {
      code, clientVersion: '6.19.3',
    }));
    await expect(service.completeMatch(11, 10)).rejects.toBeInstanceOf(code === 'P2034' ? ConflictException : InternalServerErrorException);
    expect(fixture.prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(fixture.privateMatch.status).toBe('OPEN');
  });
});
