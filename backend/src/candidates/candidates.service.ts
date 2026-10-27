import { BadRequestException, Injectable } from '@nestjs/common';
import { RoleName } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability-preference/availability.service';
import { DEFAULT_RELIABILITY_SCORE, RatingsService } from '../ratings/ratings.service';
import { CandidateQueryDto, UpdateLocationDto } from './dto/candidate.dto';
import { boundingBox, haversineKm } from './geo.util';

const DEFAULT_RADIUS_KM = 10;
const DEFAULT_CANDIDATE_LIMIT = 20;
const DEFAULT_TOP_K = 5;
const UPCOMING_DAYS = 7;
const MAX_ROWS_FROM_DB = 500;

export interface MatchmakingSearchCriteria {
  location: { latitude: number; longitude: number };
  availableTimeSlots: string[];
  maxDistanceKm: number;
  minSkillLevel?: number;
  maxSkillLevel?: number;
  playingStyles?: string[];
}

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
    private readonly ratingsService: RatingsService,
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

  async buildMatchmakingRequest(userId: number, query: CandidateQueryDto, criteria?: MatchmakingSearchCriteria) {
    const me = await this.getMyLocationOrThrow(userId, criteria?.location);
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

    const reliabilityByUser = await this.ratingsService.getReliabilityScores([userId, ...candidateIds]);

    const currentUser = await this.toPlayerInput(
      me.profile,
      myPreference,
      reliabilityByUser.get(userId) ?? DEFAULT_RELIABILITY_SCORE,
    );
    if (criteria) {
      currentUser.location = { ...criteria.location };
      currentUser.available_time_slots = [...criteria.availableTimeSlots];
      currentUser.max_distance_km = criteria.maxDistanceKm;
      currentUser.skill.preferred_min = criteria.minSkillLevel ?? currentUser.skill.preferred_min;
      currentUser.skill.preferred_max = criteria.maxSkillLevel ?? currentUser.skill.preferred_max;
      if (currentUser.skill.preferred_min > currentUser.skill.preferred_max) {
        throw new BadRequestException('Khoảng kỹ năng tìm kiếm không hợp lệ');
      }
      if (criteria.playingStyles !== undefined) currentUser.playing_style = [...criteria.playingStyles];
    }

    const candidateInputs = await Promise.all(
      nearby.map(({ profile }) =>
        this.toPlayerInput(
          profile,
          preferenceByUser.get(profile.userId) ?? null,
          reliabilityByUser.get(profile.userId) ?? DEFAULT_RELIABILITY_SCORE,
        ),
      ),
    );
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

  private async getMyLocationOrThrow(userId: number, location?: { latitude: number; longitude: number }) {
    const profile = await this.prisma.playerProfile.findUnique({
      where: { userId },
      include: { user: { select: { id: true, fullName: true } }, skill: true },
    });
    const latitude = location?.latitude ?? profile?.latitude;
    const longitude = location?.longitude ?? profile?.longitude;
    if (!profile || latitude == null || longitude == null) {
      throw new BadRequestException(
        'Bạn chưa cập nhật vị trí. Hãy gọi PUT /candidates/me/location trước.',
      );
    }
    return {
      profile: profile as ProfileWithRelations,
      latitude,
      longitude,
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
    reliabilityScore: number,
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
      reliability_score: reliabilityScore,
    };
  }

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
