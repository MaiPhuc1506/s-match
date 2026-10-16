import { Injectable } from '@nestjs/common';
import { CandidatesService, MatchmakingPlayerInput } from '../candidates/candidates.service';
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
  constructor(private readonly candidates: CandidatesService) {}

  async getCandidates(userId: number, criteria: FindPlayerDto): Promise<CandidateData> {
    const { request } = await this.candidates.buildMatchmakingRequest(
      userId, { radiusKm: criteria.maxDistanceKm, limit: 100 }, criteria,
    );
    return {
      currentUser: toCandidateProfile(request.current_user),
      candidates: request.candidates.map(toCandidateProfile),
    };
  }
}
