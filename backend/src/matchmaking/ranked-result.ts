// Internal FastAPI result. Public profile enrichment belongs to the Gateway.
export interface RankedPlayer {
  userId: string;
  matchScore: number;
}

export interface RankedResult {
  matchedUsers: RankedPlayer[];
  totalCandidatesProcessed: number;
}
