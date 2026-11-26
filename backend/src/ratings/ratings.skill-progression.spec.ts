import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { RatingsService } from './ratings.service';
import { CreateRatingDto } from './dto/rating.dto';

describe('peer skill integration', () => {
  const start = new Date(Date.now() - 3 * 3600000), end = new Date(Date.now() - 3600000);
  const match = { id: 3, privacy: 'OPEN', status: 'COMPLETED', startTime: start, endTime: end, participants: [{ userId: 1 }, { userId: 2 }] };
  const skill = { id: 1, smash: 3, defense: 3, netPlay: 3, stamina: 3, footwork: 3, serve: 3, initialScores: null, initialSource: null };
  const row = (id: number, matchId: number, raterId: number) => ({ id, matchId, raterId, skillRatings: { smash: 5, defense: null }, match: { startTime: new Date(start.getTime() + matchId), participants: [{ userId: raterId }, { userId: 2 }] } });
  let db: any, service: RatingsService;
  beforeEach(() => {
    db = { $queryRaw: jest.fn(), match: { findUnique: jest.fn().mockResolvedValue(match) },
      playerProfile: { findUnique: jest.fn().mockResolvedValue({ skill }) },
      skill: { update: jest.fn() },
      playerRating: { create: jest.fn().mockResolvedValue({ id: 3 }), findMany: jest.fn().mockResolvedValue([row(1, 1, 1), row(2, 2, 3), row(3, 3, 1)]), aggregate: jest.fn().mockResolvedValue({ _avg: { score: 4 }, _count: { _all: 3 } }) },
      ratingHistory: { create: jest.fn() } };
    db.$transaction = jest.fn(cb => cb(db));
    service = new RatingsService(db);
  });
  it('validates observations with null permitted and rejects out-of-range or unknown axes', async () => {
    const good = plainToInstance(CreateRatingDto, { matchId: 3, ratedUserId: 2, score: 5, skillRatings: { smash: 5, defense: null } });
    expect(await validate(good, { whitelist: true, forbidNonWhitelisted: true })).toHaveLength(0);
    const bad = plainToInstance(CreateRatingDto, { matchId: 3, ratedUserId: 2, score: 5, skillRatings: { smash: 0, invented: 5 } });
    expect((await validate(bad, { whitelist: true, forbidNonWhitelisted: true })).length).toBeGreaterThan(0);
  });
  it('stores observations and replays a bounded per-axis update in the same transaction', async () => {
    await service.create(1, { matchId: 3, ratedUserId: 2, score: 5, skillRatings: { smash: 5, defense: null } });
    expect(db.$transaction).toHaveBeenCalledTimes(1);
    expect(db.playerRating.create.mock.calls[0][0].data.skillRatings).toEqual({ smash: 5, defense: null });
    const update = db.skill.update.mock.calls[0][0].data;
    expect(update.smash).toBeCloseTo(3.1);
    expect(update.defense).toBe(3);
    expect(update.initialSource).toBe('LEGACY_BASELINE');
    expect(update.progressHistory.version).toBe(1);
  });
  it('preserves skill for a legacy overall-star-only rating', async () => {
    await service.create(1, { matchId: 3, ratedUserId: 2, score: 1 });
    expect(db.skill.update).not.toHaveBeenCalled();
  });
});
