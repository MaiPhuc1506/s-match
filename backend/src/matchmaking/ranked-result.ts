// Internal FastAPI result. Public profile enrichment belongs to the Gateway.
export interface MatchBreakdown {
  skill_score: number;
  distance_score: number;
  time_score: number;
  reliability_score: number;
  style_score: number;
}

export interface RankedPlayer {
  userId: string;
  matchScore: number;
  breakdown: MatchBreakdown;
}

export interface RankedResult {
  matchedUsers: RankedPlayer[];
  totalCandidatesProcessed: number;
}
