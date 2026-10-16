import { BadRequestException, ConflictException, ForbiddenException, ValidationPipe } from '@nestjs/common';
import { MatchesService } from './matches.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';
import { CreateOpenMatchDto } from './dto/open-match.dto';
import { MATCH_PARTICIPANT_MUTATION_SELECT } from './match-response.select';
import { makeMatchBookingFixture } from '../../test/helpers/matches-booking.fixture';

describe('Match validation and participant responses 2D (Prisma mock)', () => {
  let fixture: ReturnType<typeof makeMatchBookingFixture>;
  let service: MatchesService;
  const create = { title: 'Fixture', startTime: '2026-10-20T18:00:00Z', endTime: '2026-10-20T19:00:00Z' };
  const open = { mode: 'DOUBLES', purpose: 'CASUAL', neededPlayers: 2, minSkillLevel: 1, maxSkillLevel: 5 } as const;
  const pipe = new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true });
  const keys = ['id', 'matchId', 'role', 'status', 'userId'];
  beforeEach(() => {
    fixture = makeMatchBookingFixture();
    service = new MatchesService(fixture.prisma);
  });
  function noWrites() {
    for (const model of [fixture.prisma.match, fixture.prisma.matchParticipant]) {
      expect(model.create).not.toHaveBeenCalled();
      expect(model.update).not.toHaveBeenCalled();
    }
  }
  async function participantAction(action: string) {
    if (action === 'invite-new') return service.inviteUser(11, 10, 90);
    if (action === 'invite-existing') return service.inviteUser(11, 10, 60);
    if (action === 'join-new') return service.requestToJoin(12, 90);
    if (action === 'join-existing') return service.requestToJoin(12, 60);
    if (action === 'accept') return service.acceptInvitation(11, 40);
    if (action === 'reject-invite') return service.rejectInvitation(11, 40);
    if (action === 'approve') return service.hostApproveRequest(11, 10, 50);
    if (action === 'reject-request') return service.hostRejectRequest(11, 10, 50);
    return service.respondToRequest(10, 11, 4, action === 'approve-alias');
  }

  it.each(['invite-new', 'invite-existing', 'join-new', 'join-existing', 'accept', 'reject-invite', 'approve', 'reject-request', 'approve-alias', 'reject-alias'])(
    'returns exactly five participant fields via %s', async (action) => {
      const result = await participantAction(action);
      expect(Object.keys(result).sort()).toEqual(keys);
      for (const write of [fixture.prisma.matchParticipant.create, fixture.prisma.matchParticipant.update]) {
        for (const [args] of write.mock.calls) expect(args.select).toEqual(MATCH_PARTICIPANT_MUTATION_SELECT);
      }
    },
  );

  it('keeps leave acknowledgement unchanged', async () => {
    expect(await service.leave(30, 11)).toEqual({ id: 11, left: true });
  });

  it.each(['accept', 'approve', 'approve-alias'])('allows %s only for OPEN', async (action) => {
    expect(await participantAction(action)).toMatchObject({ status: 'ACCEPTED' });
  });
  for (const status of ['FULL', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED']) {
    it.each(['accept', 'approve', 'approve-alias'])('rejects %s for ' + status + ' without writes', async (action) => {
      fixture.privateMatch.status = status;
      const before = JSON.stringify(fixture.rows);
      await expect(participantAction(action)).rejects.toBeInstanceOf(ConflictException);
      noWrites();
      expect(JSON.stringify(fixture.rows)).toBe(before);
    });
  }
  it.each(['accept', 'approve'])('preserves 400 for OPEN with no room: %s', async (action) => {
    fixture.privateMatch.maxPlayers = 2;
    await expect(participantAction(action)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
  });
  it.each(['accept', 'approve'])('preserves required pending participant status: %s', async (action) => {
    fixture.privateMatch.participants[action === 'accept' ? 2 : 3].status = 'REJECTED';
    await expect(participantAction(action)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
  });
  it('checks host authorization before reporting Match state', async () => {
    fixture.privateMatch.status = 'CANCELLED';
    await expect(service.hostApproveRequest(11, 90, 50)).rejects.toBeInstanceOf(ForbiddenException);
    noWrites();
  });

  it.each([
    ['invalid', create.endTime], [create.startTime, 'invalid'],
    [null, create.endTime], [create.startTime, null],
    [new Date(NaN), new Date(create.endTime)], [create.endTime, create.startTime],
    [create.startTime, create.startTime],
  ])('rejects invalid create time pair %j / %j without writes', async (startTime, endTime) => {
    await expect(service.createMatch(10, { ...create, startTime, endTime } as any)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
  });
  it.each([
    { startTime: '2026-10-20T19:00:00Z' }, { startTime: '2026-10-20T20:00:00Z' },
    { endTime: '2026-10-20T18:00:00Z' }, { endTime: '2026-10-20T17:00:00Z' },
    { startTime: null }, { endTime: null }, { startTime: 'invalid' },
    { startTime: '2026-10-21T20:00:00Z', endTime: '2026-10-21T19:00:00Z' },
  ])('checks final merged PATCH times before mutation: %j', async (body) => {
    const before = JSON.stringify(fixture.rows);
    await expect(service.updateMatch(11, 10, body as any)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });
  it.each([
    { startTime: '2026-10-20T18:30:00Z' }, { endTime: '2026-10-20T19:30:00Z' },
    { startTime: '2026-10-21T18:00:00Z', endTime: '2026-10-21T19:00:00Z' },
    { startTime: '2026-10-20T20:00:00+02:00', endTime: '2026-10-20T18:30:00Z' },
  ])('accepts valid merged times and writes only supplied fields: %j', async (body) => {
    await service.updateMatch(11, 10, body);
    const data = fixture.prisma.match.update.mock.calls[0][0].data;
    expect(Object.keys(data).sort()).toEqual(Object.keys(body).sort());
    for (const [key, value] of Object.entries(body)) expect(data[key]).toEqual(new Date(value));
  });
  it('does not revalidate legacy times on title-only PATCH', async () => {
    fixture.privateMatch.endTime = new Date('2020-01-01');
    await service.updateMatch(11, 10, { title: 'Changed' });
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ title: 'Changed' });
  });
  it('rejects invalid PATCH time before changing a valid Booking link', async () => {
    await expect(service.updateMatch(11, 10, { bookingId: 102, endTime: create.startTime })).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
  });
  it('does not add future-time restrictions on create', async () => {
    await expect(service.createMatch(10, { ...create, startTime: '2020-01-01T10:00:00Z', endTime: '2020-01-01T11:00:00Z' })).resolves.toBeDefined();
  });
  it('rejects malformed stored Booking times before createFromBooking mutation', async () => {
    fixture.bookings.get(102).endTime = new Date(NaN);
    await expect(service.createFromBooking(10, 102, open)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
  });

  it.each([null, 0, 1, 2.5, '4', 2147483648, Infinity, NaN])('rejects maxPlayers=%j for POST/PATCH before writes', async (value) => {
    for (const type of [CreateMatchDto, UpdateMatchDto]) {
      await expect(pipe.transform(type === CreateMatchDto ? { ...create, maxPlayers: value } : { maxPlayers: value }, { type: 'body', metatype: type })).rejects.toBeInstanceOf(BadRequestException);
    }
    await expect(service.createMatch(10, { ...create, maxPlayers: value } as any)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.updateMatch(11, 10, { maxPlayers: value } as any)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
  });
  it.each([2, 2147483647])('accepts maxPlayers boundary %s in DTO and service', async (maxPlayers) => {
    for (const type of [CreateMatchDto, UpdateMatchDto]) {
      const body = type === CreateMatchDto ? { ...create, maxPlayers } : { maxPlayers };
      await expect(pipe.transform(body, { type: 'body', metatype: type })).resolves.toMatchObject({ maxPlayers });
    }
    await service.createMatch(10, { ...create, maxPlayers });
    await service.updateMatch(11, 10, { maxPlayers });
    expect(fixture.privateMatch.maxPlayers).toBe(maxPlayers);
  });
  it('preserves POST defaults and PATCH omission', async () => {
    const dto = await pipe.transform(create, { type: 'body', metatype: CreateMatchDto });
    expect(await service.createMatch(10, dto)).toMatchObject({ privacy: 'OPEN', maxPlayers: 4, feePerPlayer: 0 });
    fixture.privateMatch.maxPlayers = 8;
    await service.updateMatch(11, 10, { title: 'Changed' });
    expect(fixture.privateMatch.maxPlayers).toBe(8);
  });
  it.each([null, 0, 1.5, 2147483647, Infinity])('rejects neededPlayers=%j before adding host or mutation', async (neededPlayers) => {
    await expect(pipe.transform({ ...open, neededPlayers }, { type: 'body', metatype: CreateOpenMatchDto })).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.createFromBooking(10, 102, { ...open, neededPlayers } as any)).rejects.toBeInstanceOf(BadRequestException);
    noWrites();
  });
  it.each([1, 2147483646])('accepts neededPlayers boundary %s without overflow', async (neededPlayers) => {
    const dto = await pipe.transform({ ...open, neededPlayers }, { type: 'body', metatype: CreateOpenMatchDto });
    expect(await service.createFromBooking(10, 102, dto)).toMatchObject({ maxPlayers: neededPlayers + 1 });
  });
});
