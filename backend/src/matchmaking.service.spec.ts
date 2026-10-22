import { BadGatewayException, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { MatchmakingService } from './matchmaking.service';
import { FastApiClient } from './matchmaking/fastapi.client';
import { UnavailableCandidateProvider } from './matchmaking/candidate-provider';
import { candidateData, findPlayerRequest, recommendationProfile } from '../test/helpers/matchmaking.fixture';
import { PrismaService } from './prisma/prisma.service';

describe('MatchmakingService (dependency mocks only)', () => {
  const provider = { getCandidates: jest.fn() };
  const client = { recommend: jest.fn() };
  const prisma = { playerProfile: { findMany: jest.fn() } };
  let service: MatchmakingService;
  beforeEach(() => {
    jest.resetAllMocks();
    provider.getCandidates.mockResolvedValue(candidateData());
    client.recommend.mockResolvedValue({ matchedUsers: [{ userId: '7', matchScore: 85 }], totalCandidatesProcessed: 2 });
    prisma.playerProfile.findMany.mockResolvedValue([recommendationProfile(7)]);
    service = new MatchmakingService(provider, client as unknown as FastApiClient, prisma as unknown as PrismaService);
  });

  it('passes authenticated identity and criteria to provider, then calls FastAPI with backend data', async () => {
    const result = await service.getRecommendedMatches(8, findPlayerRequest);
    expect(provider.getCandidates).toHaveBeenCalledWith(8, findPlayerRequest);
    expect(client.recommend).toHaveBeenCalledWith(candidateData());
    expect(result).toEqual({ matchedUsers: [{ userId: '7', matchScore: 85, profile: {
      fullName: 'Fixture player 7', nickname: null, avatarUrl: null, skillLevel: null,
    } }], totalCandidatesProcessed: 2 });
  });
  it('production provider returns unavailable, never fake success', async () => {
    const unavailable = new UnavailableCandidateProvider();
    await expect(unavailable.getCandidates(8, findPlayerRequest)).rejects.toBeInstanceOf(ServiceUnavailableException);
    service = new MatchmakingService(unavailable, client as unknown as FastApiClient, prisma as unknown as PrismaService);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(client.recommend).not.toHaveBeenCalled();
  });
  it('loads all ranked profiles by userId with one PLAYER-only allowlist query', async () => {
    client.recommend.mockResolvedValue({ matchedUsers: [{ userId: '7', matchScore: 85 }, { userId: '3', matchScore: 80 }], totalCandidatesProcessed: 2 });
    prisma.playerProfile.findMany.mockResolvedValue([recommendationProfile(3), recommendationProfile(7)]);
    const result = await service.getRecommendedMatches(8, findPlayerRequest);
    expect(prisma.playerProfile.findMany).toHaveBeenCalledTimes(1);
    expect(prisma.playerProfile.findMany).toHaveBeenCalledWith({
      where: { userId: { in: [7, 3] }, user: { role: { name: 'PLAYER' } } },
      select: { userId: true, nickname: true, avatarUrl: true, skillLevel: true, user: { select: { fullName: true } } },
    });
    expect(result.matchedUsers.map((row) => [row.userId, row.matchScore, row.profile.fullName])).toEqual([
      ['7', 85, 'Fixture player 7'], ['3', 80, 'Fixture player 3'],
    ]);
  });
  it('keeps zero scores, tied scores and optional display values without sorting', async () => {
    client.recommend.mockResolvedValue({ matchedUsers: [{ userId: '7', matchScore: 0 }, { userId: '3', matchScore: 0 }], totalCandidatesProcessed: 2 });
    prisma.playerProfile.findMany.mockResolvedValue([
      recommendationProfile(3), { ...recommendationProfile(7), nickname: 'Seven', avatarUrl: 'https://example.test/avatar.png', skillLevel: 'INTERMEDIATE' },
    ]);
    const result = await service.getRecommendedMatches(8, findPlayerRequest);
    expect(result.matchedUsers.map((row) => [row.userId, row.matchScore])).toEqual([['7', 0], ['3', 0]]);
    expect(result.matchedUsers[0].profile).toEqual({ fullName: 'Fixture player 7', nickname: 'Seven', avatarUrl: 'https://example.test/avatar.png', skillLevel: 'INTERMEDIATE' });
  });
  it('keeps missing display values null and never exposes extra database properties', async () => {
    prisma.playerProfile.findMany.mockResolvedValue([{
      ...recommendationProfile(7), latitude: 16, longitude: 108, createdAt: new Date(),
      user: { fullName: null, email: 'private@example.test', phone: 'PRIVATE', password: 'PRIVATE' },
    }]);
    const result = await service.getRecommendedMatches(8, findPlayerRequest);
    expect(result.matchedUsers).toEqual([{ userId: '7', matchScore: 85, profile: {
      fullName: null, nickname: null, avatarUrl: null, skillLevel: null,
    } }]);
  });
  it('drops missing or no-longer-PLAYER profiles without replacing them or changing processed count', async () => {
    client.recommend.mockResolvedValue({ matchedUsers: [{ userId: '7', matchScore: 85 }, { userId: '3', matchScore: 80 }], totalCandidatesProcessed: 2 });
    // The database PLAYER predicate excludes removed profiles and changed roles.
    prisma.playerProfile.findMany.mockResolvedValue([recommendationProfile(3)]);
    const result = await service.getRecommendedMatches(8, findPlayerRequest);
    expect(result.matchedUsers.map((row) => row.userId)).toEqual(['3']);
    expect(result.totalCandidatesProcessed).toBe(2);
    expect(client.recommend).toHaveBeenCalledTimes(1);
  });
  it('returns an empty result when all ranked profiles disappeared', async () => {
    prisma.playerProfile.findMany.mockResolvedValue([]);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).resolves.toEqual({ matchedUsers: [], totalCandidatesProcessed: 2 });
  });
  it('skips enrichment for both no-candidate and empty-ranking paths', async () => {
    provider.getCandidates.mockResolvedValueOnce({ ...candidateData(), candidates: [] });
    await service.getRecommendedMatches(8, findPlayerRequest);
    client.recommend.mockResolvedValueOnce({ matchedUsers: [], totalCandidatesProcessed: 2 });
    await service.getRecommendedMatches(8, findPlayerRequest);
    expect(prisma.playerProfile.findMany).not.toHaveBeenCalled();
  });
  it.each(['0', '-1', '7abc', '7.5', '2147483648', '9007199254740993', '07'])('rejects invalid Prisma Int identity %s before querying profiles', async (userId) => {
    client.recommend.mockResolvedValue({ matchedUsers: [{ userId, matchScore: 85 }], totalCandidatesProcessed: 2 });
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(BadGatewayException);
    expect(prisma.playerProfile.findMany).not.toHaveBeenCalled();
  });
  it('sanitizes profile database failures as 503, without retries or empty success', async () => {
    prisma.playerProfile.findMany.mockRejectedValue(new Error('PRIVATE_DATABASE_DETAILS'));
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toMatchObject({ status: 503, message: 'Dịch vụ hồ sơ người chơi chưa sẵn sàng' });
    expect(prisma.playerProfile.findMany).toHaveBeenCalledTimes(1);
  });
  it.each([new Error('PRIVATE_PROVIDER_ERROR'), new BadRequestException('PRIVATE_PROVIDER_ERROR')])('sanitizes provider failure before calling FastAPI', async (error) => {
    provider.getCandidates.mockRejectedValueOnce(error);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toMatchObject({ status: 503, message: 'Dịch vụ dữ liệu ứng viên chưa sẵn sàng' });
    expect(client.recommend).not.toHaveBeenCalled();
  });
  it('returns a successful empty result without contacting FastAPI', async () => {
    provider.getCandidates.mockResolvedValue({ ...candidateData(), candidates: [] });
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).resolves.toEqual({ matchedUsers: [], totalCandidatesProcessed: 0 });
    expect(client.recommend).not.toHaveBeenCalled();
  });
  it.each([null, {}, { currentUser: {}, candidates: [] }])('rejects malformed provider data: %j', async (data) => {
    provider.getCandidates.mockResolvedValue(data);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(BadGatewayException);
    expect(client.recommend).not.toHaveBeenCalled();
  });
  it('rejects provider identity substitution', async () => {
    const data = candidateData();
    data.currentUser.userId = '1';
    provider.getCandidates.mockResolvedValue(data);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(BadGatewayException);
    expect(client.recommend).not.toHaveBeenCalled();
  });
  it('rejects duplicate candidate identities without filtering', async () => {
    const data = candidateData();
    data.candidates[1].userId = '3';
    provider.getCandidates.mockResolvedValue(data);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(BadGatewayException);
    expect(client.recommend).not.toHaveBeenCalled();
  });
  it('rejects reversed skill criteria before contacting provider', async () => {
    await expect(service.getRecommendedMatches(8, { ...findPlayerRequest, minSkillLevel: 5, maxSkillLevel: 2 })).rejects.toBeInstanceOf(BadRequestException);
    expect(provider.getCandidates).not.toHaveBeenCalled();
  });
  it('propagates the sanitized FastAPI error rather than returning no candidates', async () => {
    client.recommend.mockRejectedValueOnce(new BadGatewayException('Dịch vụ matchmaking phản hồi lỗi'));
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(BadGatewayException);
    expect(client.recommend).toHaveBeenCalledTimes(1);
  });
});
