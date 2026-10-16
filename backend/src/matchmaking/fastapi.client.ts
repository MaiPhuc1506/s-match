import { BadGatewayException, GatewayTimeoutException, Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AxiosInstance, isAxiosError } from 'axios';
import { finalize, firstValueFrom, from, timeout, TimeoutError } from 'rxjs';
import { CandidateData, CandidateProfile } from './candidate-provider';
import { isCandidateData, isRecord } from './candidate-data';
import { MatchmakingResponseDto } from './dto/matchmaking-response.dto';

export const FASTAPI_HTTP = Symbol('FASTAPI_HTTP');

function toFastApiProfile(profile: CandidateProfile) {
  return {
    user_id: profile.userId,
    skill: {
      smash: profile.skill.smash, defense: profile.skill.defense, net_play: profile.skill.netPlay,
      stamina: profile.skill.stamina, footwork: profile.skill.footwork, serve: profile.skill.serve,
      preferred_min: profile.skill.preferredMin, preferred_max: profile.skill.preferredMax,
    },
    available_time_slots: [...profile.availableTimeSlots],
    location: { latitude: profile.location.latitude, longitude: profile.location.longitude },
    ...(profile.maxDistanceKm !== undefined && { max_distance_km: profile.maxDistanceKm }),
    ...(profile.playingStyle !== undefined && { playing_style: [...profile.playingStyle] }),
    ...(profile.reliabilityScore !== undefined && { reliability_score: profile.reliabilityScore }),
  };
}

@Injectable()
export class FastApiClient {
  constructor(@Inject(FASTAPI_HTTP) private readonly http: AxiosInstance, private readonly config: ConfigService) {}

  async recommend(data: CandidateData): Promise<MatchmakingResponseDto> {
    if (!isCandidateData(data)) {
      throw new BadGatewayException('Dữ liệu ứng viên không hợp lệ');
    }
    const rawUrl = this.config.get<unknown>('MATCHMAKING_API_URL');
    const rawTimeout = this.config.get<unknown>('MATCHMAKING_TIMEOUT_MS');
    const timeoutMs = rawTimeout === undefined ? 5000 : Number(rawTimeout);
    let url: URL;
    try {
      if (typeof rawUrl !== 'string') throw new Error();
      url = new URL(rawUrl);
      if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.hash) throw new Error();
      if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 60000) throw new Error();
    } catch {
      throw new ServiceUnavailableException('Cấu hình dịch vụ matchmaking chưa sẵn sàng');
    }
    const payload = { current_user: toFastApiProfile(data.currentUser), candidates: data.candidates.map(toFastApiProfile) };
    let body: unknown;
    const controller = new AbortController();
    try {
      const response = await firstValueFrom(from(this.http.post<unknown>(url.toString(), payload, {
        timeout: timeoutMs, maxRedirects: 0, signal: controller.signal,
      })).pipe(timeout(timeoutMs), finalize(() => controller.abort())));
      if (response.status < 200 || response.status >= 300) throw new Error();
      body = response.data;
    } catch (error) {
      controller.abort();
      if (error instanceof TimeoutError || (isAxiosError(error) && ['ECONNABORTED', 'ETIMEDOUT'].includes(error.code || ''))) {
        throw new GatewayTimeoutException('Dịch vụ matchmaking phản hồi quá thời gian');
      }
      if (isAxiosError(error) && !error.response) {
        throw new ServiceUnavailableException('Không kết nối được dịch vụ matchmaking');
      }
      throw new BadGatewayException('Dịch vụ matchmaking phản hồi lỗi');
    }
    return this.mapResponse(body, data);
  }

  private mapResponse(body: unknown, data: CandidateData): MatchmakingResponseDto {
    const invalid = () => new BadGatewayException('Phản hồi dịch vụ matchmaking không hợp lệ');
    if (!isRecord(body) || !Array.isArray(body.matched_users) ||
        !Number.isInteger(body.total_candidates_processed) ||
        body.total_candidates_processed !== data.candidates.length) throw invalid();
    const allowed = new Set(data.candidates.map((candidate) => candidate.userId));
    const seen = new Set<string>();
    const matchedUsers = body.matched_users.map((row: unknown) => {
      if (!isRecord(row) || typeof row.user_id !== 'string' || !allowed.has(row.user_id) ||
          row.user_id === data.currentUser.userId || seen.has(row.user_id) ||
          typeof row.match_score !== 'number' || !Number.isFinite(row.match_score)) throw invalid();
      if (row.breakdown !== undefined && row.breakdown !== null && (!isRecord(row.breakdown) ||
          !['skill_score', 'time_score', 'distance_score', 'style_score', 'reliability_score']
            .every((key) => typeof (row.breakdown as Record<string, unknown>)[key] === 'number' &&
              Number.isFinite((row.breakdown as Record<string, unknown>)[key])))) throw invalid();
      seen.add(row.user_id);
      return { userId: row.user_id, matchScore: row.match_score };
    });
    return { matchedUsers, totalCandidatesProcessed: body.total_candidates_processed as number };
  }
}
