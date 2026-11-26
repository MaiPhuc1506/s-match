import { ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { CandidatesService, MatchmakingPlayerInput } from '../candidates/candidates.service';
import { activeInvitationStatuses, eligibleNearbyInvite, INVITATION_RADIUS_KM, invitationProfileSelect } from '../matches/invitation-eligibility';
import { PrismaService } from '../prisma/prisma.service';
import { AvailabilityService } from '../availability-preference/availability.service';
import { assessmentScore, effectiveSkillLevel } from '../players/skill-assessment';
import { CandidateData, CandidateProfile, CandidateProvider } from './candidate-provider';
import { FindPlayerDto } from './dto/find-player.dto';

function toCandidateProfile(input: MatchmakingPlayerInput): CandidateProfile {
  return {
    userId: input.user_id,
    skill: {
      smash: input.skill.smash,
      defense: input.skill.defense,
      netPlay: input.skill.net_play,
      stamina: input.skill.stamina,
      footwork: input.skill.footwork,
      serve: input.skill.serve,
      preferredMin: input.skill.preferred_min,
      preferredMax: input.skill.preferred_max,
    },
    availableTimeSlots: input.available_time_slots,
    location: input.location,
    maxDistanceKm: input.max_distance_km,
    playingStyle: input.playing_style,
    reliabilityScore: input.reliability_score,
  };
}

@Injectable()
export class DatabaseCandidateProvider implements CandidateProvider {
  constructor(
    private readonly candidates: CandidatesService,
    private readonly prisma: PrismaService,
    private readonly availability: AvailabilityService,
  ) {}

  async getCandidates(userId: number, criteria: FindPlayerDto): Promise<CandidateData> {
    let excluded: Set<number> | undefined;
    let scope: Awaited<ReturnType<DatabaseCandidateProvider['inviteScope']>> | undefined;
    if (criteria.matchId !== undefined) {
      scope = await this.inviteScope(criteria.matchId, userId);
      excluded = new Set(scope.match.participants.map((p) => p.userId));
      criteria = {
        ...criteria,
        location: { latitude: scope.host.latitude!, longitude: scope.host.longitude! },
        availableTimeSlots: await this.availability.getUpcomingTimeSlots(userId),
        maxDistanceKm: INVITATION_RADIUS_KM,
        minSkillLevel: scope.match.minSkillLevel,
        maxSkillLevel: scope.match.maxSkillLevel,
        playingStyles: undefined,
        skillCategory: undefined,
      };
      if (!criteria.availableTimeSlots.length) throw new ConflictException('Add availability before inviting players');
    }
    const { request } = await this.candidates.buildMatchmakingRequest(
      userId, { radiusKm: criteria.maxDistanceKm, limit: 100 },
      { ...criteria, minSkillLevel: criteria.minSkillLevel ?? 1, maxSkillLevel: criteria.maxSkillLevel ?? 5 },
    );
    let candidates = request.candidates;
    if (scope && excluded) {
      const { host, match } = scope;
      const ids = candidates.map((c) => Number(c.user_id)).filter((id) => !excluded!.has(id));
      const profiles = await this.prisma.playerProfile.findMany({
        where: { userId: { in: ids }, locationSharingEnabled: true, user: { role: { name: 'PLAYER' } } },
        select: invitationProfileSelect,
      });
      const eligible = new Set(profiles.filter((target) =>
        eligibleNearbyInvite(host, target, match.minSkillLevel, match.maxSkillLevel),
      ).map((p) => p.userId));
      candidates = candidates.filter((p) => eligible.has(Number(p.user_id)));
    } else if (criteria.skillCategory && candidates.length) {
      const profiles = await this.prisma.playerProfile.findMany({
        where: { userId: { in: candidates.map((p) => Number(p.user_id)) }, locationSharingEnabled: true },
        select: { userId: true, skill: true, skillLevel: true },
      });
      const eligible = new Set(profiles.filter((p) =>
        effectiveSkillLevel(assessmentScore(p.skill), p.skillLevel) === criteria.skillCategory,
      ).map((p) => p.userId));
      candidates = candidates.filter((p) => eligible.has(Number(p.user_id)));
    }
    return {
      currentUser: toCandidateProfile(request.current_user),
      candidates: candidates.map(toCandidateProfile),
    };
  }

  private async inviteScope(matchId: number, userId: number) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId }, select: {
        hostId: true, status: true, privacy: true, startTime: true, maxPlayers: true,
        minSkillLevel: true, maxSkillLevel: true,
        participants: { select: { userId: true, status: true } },
      },
    });
    if (!match || match.hostId !== userId) throw new ForbiddenException('Only the host can search for invitees');
    if (match.privacy !== 'OPEN' || match.status !== 'OPEN' || match.startTime <= new Date() ||
        match.participants.filter((p) => p.status === 'ACCEPTED').length >= match.maxPlayers) {
      throw new ConflictException('Match is not accepting invitations');
    }
    const host = await this.prisma.playerProfile.findFirst({
      where: { userId, locationSharingEnabled: true, user: { role: { name: 'PLAYER' } } },
      select: invitationProfileSelect,
    });
    if (host?.latitude == null || host.longitude == null) throw new ForbiddenException('Save and share location before inviting players');
    return { host, match: { ...match, participants: match.participants.filter((p) => activeInvitationStatuses.includes(p.status)) } };
  }
}
