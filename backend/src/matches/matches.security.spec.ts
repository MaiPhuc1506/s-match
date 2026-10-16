import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { ParticipantStatus } from '@prisma/client';
import { Role } from '../auth/roles.enum';
import { MatchesService } from './matches.service';
import { makeMatchSecurityFixture, expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';
import { MATCH_INVITATION_SELECT, MATCH_PUBLIC_SELECT } from './match-response.select';

describe('Match privacy and response projections (Prisma mock)', () => {
  let fixture: ReturnType<typeof makeMatchSecurityFixture>;
  let service: MatchesService;
  beforeEach(() => {
    fixture = makeMatchSecurityFixture();
    service = new MatchesService(fixture.prisma);
  });

  it('filters PRIVATE in the public query and gives the same 404 as a missing match', async () => {
    for (const id of [11, 999]) {
      await expect(service.findOneOrThrow(id)).rejects.toMatchObject({ status: 404, message: 'Không tìm thấy trận đấu' });
    }
    expect(fixture.prisma.match.findFirst).toHaveBeenCalledWith({ where: { id: 11, privacy: 'OPEN' }, select: MATCH_PUBLIC_SELECT });
    expect(fixture.prisma.match.findUnique).not.toHaveBeenCalled();
  });

  it('returns sanitized public detail and both lists without any roster', async () => {
    const values = [await service.findOneOrThrow(12), ...await service.findAll({}), ...await service.findOpenMatches()];
    expect(values).toHaveLength(3);
    for (const result of values) {
      expect(result).toMatchObject({ id: 12, participantCount: 2 });
      expect(result).not.toHaveProperty('participants');
      expect(result).not.toHaveProperty('bookingId');
      expectSafeMatchResponse(result);
    }
  });

  it.each([{ id: 10, role: Role.PLAYER }, { id: 80, role: Role.ADMIN }])('allows host/admin $id detailed private access', async (actor) => {
    const result: any = await service.findOne(11, actor);
    expect(result.participants).toHaveLength(6);
    expectSafeMatchResponse(result);
  });

  it('allows ACCEPTED but returns only the accepted roster', async () => {
    const result: any = await service.findOne(11, { id: 30, role: Role.PLAYER });
    expect(result.participants).toHaveLength(2);
    expect(result.participants.every((p: any) => p.status === ParticipantStatus.ACCEPTED)).toBe(true);
    expectSafeMatchResponse(result);
  });

  it('limits INVITED to an invitation preview at query level', async () => {
    const result = await service.findOne(11, { id: 40, role: Role.PLAYER });
    expect(result).toMatchObject({ id: 11, title: 'Private fixture' });
    for (const key of ['participants', 'booking', 'bookingId', 'participantCount']) expect(result).not.toHaveProperty(key);
    expect(fixture.prisma.match.findUnique.mock.calls[1][0].select).toBe(MATCH_INVITATION_SELECT);
    expectSafeMatchResponse(result);
  });

  it.each([50, 60, 70, 90])('rejects unauthorized private reader %s before the response query', async (id) => {
    await expect(service.findOne(11, { id, role: Role.PLAYER })).rejects.toBeInstanceOf(ForbiddenException);
    expect(fixture.prisma.match.findUnique).toHaveBeenCalledTimes(1);
  });

  it('does not treat court ownership as private match access', async () => {
    await expect(service.findOne(11, { id: 20, role: Role.OWNER })).rejects.toBeInstanceOf(ForbiddenException);
  });

  it.each([Role.PLAYER, Role.OWNER, Role.ADMIN])('preserves OPEN detail access for %s', async (role) => {
    const result = await service.findOne(12, { id: 90, role });
    expect(result).toMatchObject({ id: 12 });
    expectSafeMatchResponse(result);
  });

  it('returns 404 for a missing authenticated match', async () => {
    await expect(service.findOne(999, { id: 90, role: Role.PLAYER })).rejects.toBeInstanceOf(NotFoundException);
  });

  it.each(['privacy', 'membership'])('rechecks %s changes between ACL and response queries', async (change) => {
    const query = fixture.prisma.match.findUnique.getMockImplementation();
    fixture.prisma.match.findUnique.mockImplementationOnce(async (args: any) => {
      const access = await query(args);
      if (change === 'privacy') fixture.openMatch.privacy = 'PRIVATE';
      else fixture.privateMatch.participants[1].status = 'CANCELLED';
      return access;
    });
    await expect(service.findOne(change === 'privacy' ? 12 : 11, { id: change === 'privacy' ? 90 : 30, role: Role.PLAYER })).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('returns 404 if the match disappears between ACL and response queries', async () => {
    const query = fixture.prisma.match.findUnique.getMockImplementation();
    fixture.prisma.match.findUnique.mockImplementationOnce(async (args: any) => {
      const access = await query(args);
      fixture.rows.splice(0, 1);
      return access;
    });
    await expect(service.findOne(11, { id: 30, role: Role.PLAYER })).rejects.toBeInstanceOf(NotFoundException);
  });

  it.each([Role.ADMIN, Role.OWNER])('does not grant %s non-host mutation rights', async (role) => {
    const id = role === Role.ADMIN ? 80 : 20;
    await expect(service.updateMatch(11, id, { title: 'Denied' })).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.cancelMatch(11, id)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.inviteUser(11, id, 90)).rejects.toBeInstanceOf(ForbiddenException);
    await expect(service.respondToRequest(id, 11, 4, true)).rejects.toBeInstanceOf(ForbiddenException);
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
    expect(fixture.prisma.matchParticipant.update).not.toHaveBeenCalled();
  });

  it('leaves a PRIVATE match without a forbidden detail read after the write', async () => {
    await expect(service.leave(30, 11)).resolves.toEqual({ id: 11, left: true });
    await expect(service.findOne(11, { id: 30, role: Role.PLAYER })).rejects.toBeInstanceOf(ForbiddenException);
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
  });

  it('keeps host cancel/update responses sanitized', async () => {
    expectSafeMatchResponse(await service.updateMatch(11, 10, { title: 'Updated' }));
    expectSafeMatchResponse(await service.cancelMatch(11, 10));
  });

  it('keeps invite, accept, reject and host approval flows on internal reads', async () => {
    await service.inviteUser(11, 10, 90);
    await expect(service.acceptInvitation(11, 40)).resolves.toMatchObject({ userId: 40, status: 'ACCEPTED' });
    fixture.privateMatch.participants[2].status = 'INVITED';
    await expect(service.rejectInvitation(11, 40)).resolves.toMatchObject({ userId: 40, status: 'REJECTED' });
    await expect(service.respondToRequest(10, 11, 4, true)).resolves.toMatchObject({ userId: 50, status: 'ACCEPTED' });
    fixture.privateMatch.participants[3].status = 'REQUESTED';
    await expect(service.respondToRequest(10, 11, 4, false)).resolves.toMatchObject({ userId: 50, status: 'REJECTED' });
  });

  it('keeps OPEN joining and PRIVATE join rejection', async () => {
    await expect(service.requestToJoin(11, 90)).rejects.toThrow();
    await expect(service.requestToJoin(12, 90)).resolves.toMatchObject({ userId: 90, status: 'REQUESTED' });
  });

  it('sanitizes create responses without adding Booking writes', async () => {
    expectSafeMatchResponse(await service.createMatch(10, {
      title: 'Fixture', startTime: '2026-10-20T18:00:00Z', endTime: '2026-10-20T19:00:00Z',
    }));
    expectSafeMatchResponse(await service.createFromBooking(10, 100, {
      mode: 'DOUBLES', purpose: 'CASUAL', neededPlayers: 2, minSkillLevel: 1, maxSkillLevel: 5,
    } as any));
    expect(Object.keys(fixture.prisma.booking)).toEqual(['findUnique']);
  });
});
