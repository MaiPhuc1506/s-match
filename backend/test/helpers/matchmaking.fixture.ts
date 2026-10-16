import { CandidateData, CandidateProfile } from '../../src/matchmaking/candidate-provider';
import { FindPlayerDto } from '../../src/matchmaking/dto/find-player.dto';

// Test-only normalized backend data. Never imported by production providers.
export function candidateProfile(userId: string): CandidateProfile {
  return {
    userId,
    skill: { smash: 3, defense: 3, netPlay: 3, stamina: 3, footwork: 3, serve: 3, preferredMin: 2, preferredMax: 4 },
    availableTimeSlots: ['2026-10-20T18:00:00Z'],
    location: { latitude: 16, longitude: 108 },
    maxDistanceKm: 10, playingStyle: ['aggressive'], reliabilityScore: 5,
  };
}

export function candidateData(): CandidateData {
  return { currentUser: candidateProfile('8'), candidates: [candidateProfile('3'), candidateProfile('7')] };
}

export const findPlayerRequest: FindPlayerDto = {
  availableTimeSlots: ['2026-10-20T18:00:00Z'],
  location: { latitude: 16, longitude: 108 }, maxDistanceKm: 10,
};

export function fastApiResponse() {
  return { matched_users: [{ user_id: '7', match_score: 85 }, { user_id: '3', match_score: 80 }], total_candidates_processed: 2 };
}
