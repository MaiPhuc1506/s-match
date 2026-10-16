import { AxiosInstance } from 'axios';
import { ConfigService } from '@nestjs/config';
import { FastApiClient } from './fastapi.client';
import { candidateData, fastApiResponse } from '../../test/helpers/matchmaking.fixture';

describe('FastApiClient (HTTP dependency mock; no upstream connection)', () => {
  const http = { post: jest.fn() };
  const config = { get: jest.fn() };
  let settings: Record<string, unknown>;
  let client: FastApiClient;
  beforeEach(() => {
    jest.resetAllMocks();
    settings = { MATCHMAKING_API_URL: 'http://matchmaking.test/api/v1/match', MATCHMAKING_TIMEOUT_MS: 30 };
    config.get.mockImplementation((key) => settings[key]);
    http.post.mockResolvedValue({ status: 200, data: fastApiResponse() });
    client = new FastApiClient(http as unknown as AxiosInstance, config as unknown as ConfigService);
  });
  it('maps backend profiles to unchanged FastAPI schema and maps only allowed result fields', async () => {
    const data = candidateData();
    Object.assign(data.currentUser, { email: 'not-public', password: 'not-public' });
    Object.assign(data.candidates[0].location, { secret: 'not-public' });
    const upstream = fastApiResponse();
    Object.assign(upstream, { secret: 'not-public' });
    Object.assign(upstream.matched_users[0], { email: 'not-public' });
    http.post.mockResolvedValue({ status: 200, data: upstream });
    const result = await client.recommend(data);
    const [url, payload, options] = http.post.mock.calls[0];
    expect(url).toBe(settings.MATCHMAKING_API_URL);
    expect(options).toEqual({ timeout: 30, maxRedirects: 0, signal: expect.any(AbortSignal) });
    expect(Object.keys(payload).sort()).toEqual(['candidates', 'current_user']);
    expect(payload.current_user).toEqual({
      user_id: '8', skill: { smash: 3, defense: 3, net_play: 3, stamina: 3, footwork: 3, serve: 3, preferred_min: 2, preferred_max: 4 },
      available_time_slots: ['2026-10-20T18:00:00Z'], location: { latitude: 16, longitude: 108 },
      max_distance_km: 10, playing_style: ['aggressive'], reliability_score: 5,
    });
    expect(JSON.stringify(payload)).not.toContain('not-public');
    expect(result).toEqual({ matchedUsers: [{ userId: '7', matchScore: 85 }, { userId: '3', matchScore: 80 }], totalCandidatesProcessed: 2 });
    // Preserve upstream order; the Gateway never ranks or computes scores.
    expect(http.post).toHaveBeenCalledTimes(1);
  });
  it('leaves optional Python defaults to Python, preserving explicit zero/null', async () => {
    const data = candidateData();
    delete data.currentUser.playingStyle;
    delete data.currentUser.reliabilityScore;
    data.currentUser.maxDistanceKm = null;
    data.candidates[0].maxDistanceKm = 0;
    data.candidates[0].reliabilityScore = 0;
    await client.recommend(data);
    const payload = http.post.mock.calls[0][1];
    expect(payload.current_user).not.toHaveProperty('playing_style');
    expect(payload.current_user).not.toHaveProperty('reliability_score');
    expect(payload.current_user.max_distance_km).toBeNull();
    expect(payload.candidates[0]).toMatchObject({ max_distance_km: 0, reliability_score: 0 });
  });
  it('uses 5000ms as the documented default timeout', async () => {
    delete settings.MATCHMAKING_TIMEOUT_MS;
    await client.recommend(candidateData());
    expect(http.post.mock.calls[0][2].timeout).toBe(5000);
  });
  it.each([undefined, '', 'invalid', 'file:///api/v1/match', 'http://user:password@matchmaking.test/api/v1/match', 'http://matchmaking.test/#fragment'])(
    'rejects unavailable/invalid URL configuration without HTTP', async (value) => {
      settings.MATCHMAKING_API_URL = value;
      await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 503 });
      expect(http.post).not.toHaveBeenCalled();
    },
  );
  it.each([0, -1, 1.5, 60001, 'invalid', null])('rejects invalid timeout configuration %j', async (value) => {
    settings.MATCHMAKING_TIMEOUT_MS = value;
    await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 503 });
    expect(http.post).not.toHaveBeenCalled();
  });
  it.each(['ECONNABORTED', 'ETIMEDOUT'])('maps Axios timeout %s to sanitized 504, without retry', async (code) => {
    http.post.mockRejectedValue({ isAxiosError: true, code, message: 'PRIVATE_UPSTREAM_DETAILS' });
    await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 504, message: 'Dịch vụ matchmaking phản hồi quá thời gian' });
    expect(http.post).toHaveBeenCalledTimes(1);
  });
  it('bounds a never-responding upstream observable', async () => {
    http.post.mockReturnValue(new Promise(() => {}));
    await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 504 });
    expect(http.post).toHaveBeenCalledTimes(1);
    expect(http.post.mock.calls[0][2].signal.aborted).toBe(true);
  });
  it.each(['ECONNREFUSED', 'ENOTFOUND', 'ECONNRESET'])('maps connection failure %s to sanitized 503', async (code) => {
    http.post.mockRejectedValue({ isAxiosError: true, code, message: 'PRIVATE_UPSTREAM_DETAILS' });
    await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 503, message: 'Không kết nối được dịch vụ matchmaking' });
    expect(http.post).toHaveBeenCalledTimes(1);
  });
  it.each([400, 401, 422, 429, 500, 503])('maps upstream HTTP %s to sanitized 502', async (status) => {
    http.post.mockRejectedValue({ isAxiosError: true, response: { status, data: 'PRIVATE_UPSTREAM_DETAILS' } });
    await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 502, message: 'Dịch vụ matchmaking phản hồi lỗi' });
    expect(http.post).toHaveBeenCalledTimes(1);
  });
  it.each([
    null, [], {}, { matched_users: [], total_candidates_processed: '2' },
    { matched_users: [], total_candidates_processed: -1 }, { matched_users: [], total_candidates_processed: 3 },
    { matched_users: [{ user_id: '999', match_score: 80 }], total_candidates_processed: 2 },
    { matched_users: [{ user_id: '8', match_score: 80 }], total_candidates_processed: 2 },
    { matched_users: [{ user_id: '7', match_score: '80' }], total_candidates_processed: 2 },
    { matched_users: [{ user_id: '7', match_score: NaN }], total_candidates_processed: 2 },
    { matched_users: [{ user_id: '7', match_score: Infinity }], total_candidates_processed: 2 },
    { matched_users: [{ user_id: '7', match_score: 80 }, { user_id: '7', match_score: 80 }], total_candidates_processed: 2 },
    { matched_users: [{ user_id: '7', match_score: 80, breakdown: {} }], total_candidates_processed: 2 },
  ])('rejects malformed or inconsistent upstream body: %j', async (data) => {
    http.post.mockResolvedValue({ status: 200, data });
    await expect(client.recommend(candidateData())).rejects.toMatchObject({ status: 502, message: 'Phản hồi dịch vụ matchmaking không hợp lệ' });
  });
  it('accepts valid optional breakdown without exposing it', async () => {
    const body = fastApiResponse();
    Object.assign(body.matched_users[0], { breakdown: { skill_score: 1, time_score: 2, distance_score: 3, style_score: 4, reliability_score: 5 } });
    http.post.mockResolvedValue({ status: 200, data: body });
    const result = await client.recommend(candidateData());
    expect(result.matchedUsers[0]).toEqual({ userId: '7', matchScore: 85 });
  });
  it('returns no-result from FastAPI without fabricating a match', async () => {
    http.post.mockResolvedValue({ status: 200, data: { matched_users: [], total_candidates_processed: 2 } });
    await expect(client.recommend(candidateData())).resolves.toEqual({ matchedUsers: [], totalCandidatesProcessed: 2 });
  });
  it.each([
    (data: ReturnType<typeof candidateData>) => { data.currentUser.skill.smash = NaN; },
    (data: ReturnType<typeof candidateData>) => { data.candidates[0].location.latitude = 91; },
    (data: ReturnType<typeof candidateData>) => { data.currentUser.availableTimeSlots = ['invalid']; },
    (data: ReturnType<typeof candidateData>) => { data.currentUser.skill.preferredMin = 5; data.currentUser.skill.preferredMax = 1; },
  ])('rejects invalid backend data before any HTTP request', async (mutate) => {
    const data = candidateData();
    mutate(data);
    await expect(client.recommend(data)).rejects.toMatchObject({ status: 502 });
    expect(http.post).not.toHaveBeenCalled();
  });
});
