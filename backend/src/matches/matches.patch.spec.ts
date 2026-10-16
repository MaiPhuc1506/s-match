import { BadRequestException, ValidationPipe } from '@nestjs/common';
import { MatchesService } from './matches.service';
import { UpdateMatchDto } from './dto/update-match.dto';
import { CreateMatchDto, MatchPrivacyDto } from './dto/create-match.dto';
import { makeMatchBookingFixture } from '../../test/helpers/matches-booking.fixture';
import { expectSafeMatchResponse } from '../../test/helpers/matches-security.fixture';

describe('PATCH Match field presence (Prisma mock)', () => {
  let fixture: ReturnType<typeof makeMatchBookingFixture>;
  let service: MatchesService;
  const pipe = new ValidationPipe({ transform: true, whitelist: true, forbidNonWhitelisted: true });
  const transform = (body: object) => pipe.transform(body, { type: 'body', metatype: UpdateMatchDto });
  const patch = async (body: object) => service.updateMatch(11, 10, await transform(body));
  beforeEach(() => {
    fixture = makeMatchBookingFixture();
    Object.assign(fixture.privateMatch, { maxPlayers: 8, feePerPlayer: 75000 });
    service = new MatchesService(fixture.prisma);
  });

  it('title-only PATCH preserves PRIVATE, capacity, fee, Booking and status', async () => {
    const before = { ...fixture.privateMatch };
    const result = await patch({ title: 'Changed title' });
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ title: 'Changed title' });
    expect(fixture.privateMatch).toEqual({ ...before, title: 'Changed title' });
    expectSafeMatchResponse(result);
    expect(fixture.prisma.booking.findUnique).not.toHaveBeenCalled();
    expect(fixture.prisma.$transaction).not.toHaveBeenCalled();
  });

  it('a repeated current Booking is validated, remains a no-op, and inherits no defaults', async () => {
    const before = JSON.stringify(fixture.rows);
    const result = await patch({ bookingId: 100 });
    expect(JSON.stringify(fixture.rows)).toBe(before);
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
    expect(fixture.prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(fixture.prisma.$queryRaw).toHaveBeenCalledTimes(1);
    expectSafeMatchResponse(result);
  });

  it('changing the Booking writes only bookingId and preserves other fields', async () => {
    await patch({ bookingId: 102 });
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ bookingId: 102 });
    expect(fixture.privateMatch).toMatchObject({ privacy: 'PRIVATE', maxPlayers: 8, feePerPlayer: 75000 });
    expect(fixture.prisma.$transaction).toHaveBeenCalledTimes(1);
  });

  it.each([MatchPrivacyDto.OPEN, MatchPrivacyDto.PRIVATE])('explicit privacy %s is written', async (privacy) => {
    fixture.privateMatch.privacy = privacy === MatchPrivacyDto.OPEN ? 'PRIVATE' : 'OPEN';
    await patch({ privacy });
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ privacy });
    expect(fixture.privateMatch.privacy).toBe(privacy);
  });

  it.each([{ feePerPlayer: 0 }, { maxPlayers: 6 }])('writes a deliberate valid value: %j', async (body) => {
    await patch(body);
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual(body);
    expect(fixture.privateMatch).toMatchObject(body);
  });

  it('empty and undefined fields are omitted without mutation', async () => {
    const before = JSON.stringify(fixture.rows);
    await patch({});
    await service.updateMatch(11, 10, { title: undefined, privacy: undefined, feePerPlayer: undefined, bookingId: undefined });
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });

  it('does not copy inherited scalar properties from internal callers', async () => {
    const dto = Object.assign(Object.create({ privacy: 'OPEN', maxPlayers: 4 }), { title: 'Own title' });
    await service.updateMatch(11, 10, dto);
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ title: 'Own title' });
  });

  it('preserves explicit null clearing for existing nullable scalars', async () => {
    await patch({ description: null, location: null, feePerPlayer: null });
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ description: null, location: null, feePerPlayer: null });
  });

  it.each([
    { privacy: null }, { privacy: 'INVALID' }, { maxPlayers: null },
    { maxPlayers: 1 }, { maxPlayers: 2.5 }, { maxPlayers: '8' },
    { feePerPlayer: '0' }, { feePerPlayer: NaN }, { title: '' },
    { title: null }, { startTime: null }, { endTime: null },
    { startTime: 'invalid' }, { description: 1 }, { location: 1 }, { bookingId: null },
  ])('rejects invalid PATCH before mutation: %j', async (body) => {
    const before = JSON.stringify(fixture.rows);
    await expect(patch(body)).rejects.toBeInstanceOf(BadRequestException);
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
    expect(JSON.stringify(fixture.rows)).toBe(before);
  });

  it.each(['hostId', 'userId', 'host', 'participants', 'status'])('rejects injected %s at the HTTP validation boundary', async (field) => {
    await expect(patch({ title: 'Changed', [field]: 20 })).rejects.toBeInstanceOf(BadRequestException);
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
  });

  it('service allowlist also ignores identity, relations and status from internal callers', async () => {
    await service.updateMatch(11, 10, { title: 'Changed', hostId: 20, userId: 20, host: { connect: { id: 20 } }, status: 'CANCELLED' } as any);
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ title: 'Changed' });
  });

  it('converts explicitly supplied timestamps and leaves everything else alone', async () => {
    const body = { startTime: '2026-10-21T18:00:00Z', endTime: '2026-10-21T20:00:00Z' };
    await patch(body);
    expect(fixture.prisma.match.update.mock.calls[0][0].data).toEqual({ startTime: new Date(body.startTime), endTime: new Date(body.endTime) });
  });

  it('POST still inherits its original OPEN/4/0 defaults', async () => {
    const dto = await pipe.transform({ title: 'Create', startTime: '2026-10-21T18:00:00Z', endTime: '2026-10-21T20:00:00Z' }, { type: 'body', metatype: CreateMatchDto });
    expect(dto).toMatchObject({ privacy: 'OPEN', maxPlayers: 4, feePerPlayer: 0 });
    const result = await service.createMatch(10, dto);
    expect(result).toMatchObject({ privacy: 'OPEN', maxPlayers: 4, feePerPlayer: 0 });
    expectSafeMatchResponse(result);
  });
});
