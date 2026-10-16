import { BadGatewayException, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { MatchmakingService } from './matchmaking.service';
import { FastApiClient } from './matchmaking/fastapi.client';
import { UnavailableCandidateProvider } from './matchmaking/candidate-provider';
import { candidateData, findPlayerRequest } from '../test/helpers/matchmaking.fixture';

describe('MatchmakingService (dependency mocks only)', () => {
  const provider = { getCandidates: jest.fn() };
  const client = { recommend: jest.fn() };
  let service: MatchmakingService;
  beforeEach(() => {
    jest.resetAllMocks();
    provider.getCandidates.mockResolvedValue(candidateData());
    client.recommend.mockResolvedValue({ matchedUsers: [{ userId: '7', matchScore: 85 }], totalCandidatesProcessed: 2 });
    service = new MatchmakingService(provider, client as unknown as FastApiClient);
  });

  it('passes authenticated identity and criteria to provider, then calls FastAPI with backend data', async () => {
    const result = await service.getRecommendedMatches(8, findPlayerRequest);
    expect(provider.getCandidates).toHaveBeenCalledWith(8, findPlayerRequest);
    expect(client.recommend).toHaveBeenCalledWith(candidateData());
    expect(result).toEqual({ matchedUsers: [{ userId: '7', matchScore: 85 }], totalCandidatesProcessed: 2 });
  });
  it('production provider returns unavailable, never fake success', async () => {
    const unavailable = new UnavailableCandidateProvider();
    await expect(unavailable.getCandidates(8, findPlayerRequest)).rejects.toBeInstanceOf(ServiceUnavailableException);
    service = new MatchmakingService(unavailable, client as unknown as FastApiClient);
    await expect(service.getRecommendedMatches(8, findPlayerRequest)).rejects.toBeInstanceOf(ServiceUnavailableException);
    expect(client.recommend).not.toHaveBeenCalled();
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
