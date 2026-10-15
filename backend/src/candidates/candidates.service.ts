import { BadRequestException, Injectable } from '@nestjs/common';
import { RoleName } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability-preference/availability.service';
import { CandidateQueryDto, UpdateLocationDto } from './dto/candidate.dto';
import { boundingBox, haversineKm } from './geo.util';

const DEFAULT_RADIUS_KM = 10;
const DEFAULT_CANDIDATE_LIMIT = 20;
const DEFAULT_TOP_K = 5;
const UPCOMING_DAYS = 7;
// Giới hạn số dòng lấy từ DB sau bước lọc bounding-box, để tránh nạp quá nhiều vào bộ nhớ.
const MAX_ROWS_FROM_DB = 500;
// Chưa có module Feedback (SMM-36) nên chưa có điểm uy tín thật — dùng mặc định như Matchmaking Service.
const DEFAULT_RELIABILITY_SCORE = 5.0;

/** Khớp 1-1 với PlayerProfileInput trong matchmaking/app/schemas.py */
export interface MatchmakingPlayerInput {
  user_id: string;
  skill: {
    smash: number;
    defense: number;
    net_play: number;
    stamina: number;
    footwork: number;
    serve: number;
    preferred_min: number;
    preferred_max: number;
  };
  available_time_slots: string[];
  location: { latitude: number; longitude: number };
  max_distance_km: number;
  playing_style: string[];
  reliability_score: number;
}

type ProfileWithRelations = {
  userId: number;
  nickname: string | null;
  skillLevel: string | null;
  latitude: number | null;
  longitude: number | null;
  user: { id: number; fullName: string | null };
  skill: {
    smash: number;
    defense: number;
    netPlay: number;
    stamina: number;
    footwork: number;
    serve: number;
  } | null;
};

type PreferenceLike = {
  minSkillLevel: number;
  maxSkillLevel: number;
  maxDistanceKm: number;
} | null;

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

@Injectable()
export class CandidatesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly availabilityService: AvailabilityService,
  ) {}

  async updateMyLocation(userId: number, dto: UpdateLocationDto) {
    const profile = await this.prisma.playerProfile.upsert({
      where: { userId },
      update: {
        latitude: dto.latitude,
        longitude: dto.longitude,
        locationUpdatedAt: new Date(),
      },
      create: {
        userId,
        latitude: dto.latitude,
        longitude: dto.longitude,
        locationUpdatedAt: new Date(),
      },
    });
    return {
      latitude: profile.latitude,
      longitude: profile.longitude,
      locationUpdatedAt: profile.locationUpdatedAt,
    };
  }

  // Geo Search: người chơi PLAYER khác trong bán kính, gần nhất trước
  async findNearby(userId: number, query: CandidateQueryDto) {
    const me = await this.getMyLocationOrThrow(userId);
    const preference = await this.getPreference(userId);
    const radiusKm = query.radiusKm ?? preference?.maxDistanceKm ?? DEFAULT_RADIUS_KM;
    const limit = query.limit ?? DEFAULT_CANDIDATE_LIMIT;

    const nearby = await this.searchNearbyProfiles(userId, me.latitude, me.longitude, radiusKm, limit);

    return {
      radiusKm,
      total: nearby.length,
      candidates: nearby.map(({ profile, distanceKm }) => ({
        userId: profile.userId,
        fullName: profile.user.fullName,
        nickname: profile.nickname,
        skillLevel: profile.skillLevel,
        latitude: profile.latitude,
        longitude: profile.longitude,
        distanceKm,
      })),
    };
  }

  async buildMatchmakingRequest(userId: number, query: CandidateQueryDto) {
    const me = await this.getMyLocationOrThrow(userId);
    const myPreference = await this.getPreference(userId);
    const radiusKm = query.radiusKm ?? myPreference?.maxDistanceKm ?? DEFAULT_RADIUS_KM;
    const limit = query.limit ?? DEFAULT_CANDIDATE_LIMIT;
    const topK = query.topK ?? DEFAULT_TOP_K;

    const nearby = await this.searchNearbyProfiles(userId, me.latitude, me.longitude, radiusKm, limit);

    const candidateIds = nearby.map((n) => n.profile.userId);
    const preferences = candidateIds.length
      ? await this.prisma.playingPreference.findMany({ where: { userId: { in: candidateIds } } })
      : [];
    const preferenceByUser = new Map(preferences.map((p) => [p.userId, p]));

    const currentUser = await this.toPlayerInput(me.profile, myPreference);

    const candidateInputs = await Promise.all(
      nearby.map(({ profile }) =>
        this.toPlayerInput(profile, preferenceByUser.get(profile.userId) ?? null),
      ),
    );
    // Không có lịch rảnh thì chắc chắn bị bộ lọc cứng của Matchmaking Service loại → bỏ luôn cho nhẹ payload
    const candidates = candidateInputs.filter((c) => c.available_time_slots.length > 0);

    return {
      request: { current_user: currentUser, candidates, limit: topK },
      meta: {
        radiusKm,
        candidatesInRadius: nearby.length,
        candidatesSent: candidates.length,
      },
    };
  }

  private async getPreference(userId: number): Promise<PreferenceLike> {
    return this.prisma.playingPreference.findUnique({ where: { userId } });
  }

  private async getMyLocationOrThrow(userId: number) {
    const profile = await this.prisma.playerProfile.findUnique({
      where: { userId },
      include: { user: { select: { id: true, fullName: true } }, skill: true },
    });
    if (!profile || profile.latitude == null || profile.longitude == null) {
      throw new BadRequestException(
        'Bạn chưa cập nhật vị trí. Hãy gọi PUT /candidates/me/location trước.',
      );
    }
    return {
      profile: profile as ProfileWithRelations,
      latitude: profile.latitude,
      longitude: profile.longitude,
    };
  }

  private async searchNearbyProfiles(
    userId: number,
    latitude: number,
    longitude: number,
    radiusKm: number,
    limit: number,
  ) {
    const box = boundingBox(latitude, longitude, radiusKm);

    const rows = await this.prisma.playerProfile.findMany({
      where: {
        userId: { not: userId },
        latitude: { gte: box.minLat, lte: box.maxLat },
        longitude: { gte: box.minLon, lte: box.maxLon },
        user: { role: { name: RoleName.PLAYER } },
      },
      include: { user: { select: { id: true, fullName: true } }, skill: true },
      take: MAX_ROWS_FROM_DB,
    });

    return (rows as ProfileWithRelations[])
      .map((profile) => ({
        profile,
        distanceKm: Math.round(
          haversineKm(latitude, longitude, profile.latitude as number, profile.longitude as number) * 100,
        ) / 100,
      }))
      .filter((item) => item.distanceKm <= radiusKm)
      .sort((a, b) => a.distanceKm - b.distanceKm)
      .slice(0, limit);
  }

  private async toPlayerInput(
    profile: ProfileWithRelations,
    preference: PreferenceLike,
  ): Promise<MatchmakingPlayerInput> {
    const skill = profile.skill;
    const axes = {
      smash: clamp(skill?.smash ?? 0, 0, 5),
      defense: clamp(skill?.defense ?? 0, 0, 5),
      net_play: clamp(skill?.netPlay ?? 0, 0, 5),
      stamina: clamp(skill?.stamina ?? 0, 0, 5),
      footwork: clamp(skill?.footwork ?? 0, 0, 5),
      serve: clamp(skill?.serve ?? 0, 0, 5),
    };

    const slots = await this.availabilityService.getUpcomingTimeSlots(profile.userId, UPCOMING_DAYS);

    return {
      user_id: String(profile.userId),
      skill: {
        ...axes,
        preferred_min: clamp(preference?.minSkillLevel ?? 1, 1, 5),
        preferred_max: clamp(preference?.maxSkillLevel ?? 5, 1, 5),
      },
      available_time_slots: slots,
      location: {
        latitude: profile.latitude as number,
        longitude: profile.longitude as number,
      },
      max_distance_km: preference?.maxDistanceKm ?? DEFAULT_RADIUS_KM,
      playing_style: this.derivePlayingStyle(axes),
      reliability_score: DEFAULT_RELIABILITY_SCORE,
    };
  }

  /**
   * Suy ra phong cách chơi từ 6 chỉ số kỹ năng, dùng cùng từ vựng với dataset của
   * Matchmaking Service: "Attack" | "Defense" | "Balanced". Chưa có dữ liệu kỹ năng → [].
   */
  private derivePlayingStyle(axes: {
    smash: number;
    defense: number;
    net_play: number;
    stamina: number;
    footwork: number;
    serve: number;
  }): string[] {
    const total = Object.values(axes).reduce((sum, v) => sum + v, 0);
    if (total === 0) return [];

    const attack = (axes.smash + axes.net_play + axes.serve) / 3;
    const defense = (axes.defense + axes.stamina + axes.footwork) / 3;
    if (attack - defense >= 0.5) return ['Attack'];
    if (defense - attack >= 0.5) return ['Defense'];
    return ['Balanced'];
  }
}
