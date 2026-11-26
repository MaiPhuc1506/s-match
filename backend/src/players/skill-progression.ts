/** Pure replay only. The caller must validate eligibility and persist atomically. */
export type SkillObservation = { matchId: number; matchStartedAt: Date; reviewerId: number; value: number };
export type SkillStep = { matchId: number; matchCount: number; reviewerCount: number; observedMean: number; before: number; delta: number; after: number };
const clamp = (x: number, min: number, max: number) => Math.min(max, Math.max(min, x));

/** Replay from baseline in match order; one bounded adjustment per distinct match. */
export function replaySkillAxis(baseline: number, observations: readonly SkillObservation[]): { score: number; steps: SkillStep[] } {
  if (!Number.isFinite(baseline) || baseline < 1 || baseline > 5) throw new RangeError('Invalid skill baseline');
  const byMatch = new Map<number, SkillObservation[]>();
  const seen = new Set<string>();
  for (const item of observations) {
    if (!Number.isInteger(item.matchId) || item.matchId < 1 || !Number.isInteger(item.reviewerId) || item.reviewerId < 1 ||
        !Number.isInteger(item.value) || item.value < 1 || item.value > 5 || !Number.isFinite(item.matchStartedAt.getTime())) throw new RangeError('Invalid observation');
    const key = `${item.matchId}:${item.reviewerId}`;
    if (seen.has(key)) throw new RangeError('Duplicate reviewer observation');
    seen.add(key);
    const group = byMatch.get(item.matchId) ?? [];
    if (group.length && group[0].matchStartedAt.getTime() !== item.matchStartedAt.getTime()) throw new RangeError('Inconsistent match timestamp');
    group.push(item);
    byMatch.set(item.matchId, group);
  }
  const groups = [...byMatch.values()].sort((a, b) => a[0].matchStartedAt.getTime() - b[0].matchStartedAt.getTime() || a[0].matchId - b[0].matchId);
  let score = baseline, sum = 0, count = 0;
  const reviewers = new Set<number>();
  const steps: SkillStep[] = [];
  for (const [i, group] of groups.entries()) {
    for (const item of group) { sum += item.value; count++; reviewers.add(item.reviewerId); }
    const mean = sum / count, before = score;
    if (i + 1 >= 3 && reviewers.size >= 2) score = clamp(score + clamp(0.2 * (mean - score), -0.1, 0.1), 1, 5);
    steps.push({ matchId: group[0].matchId, matchCount: i + 1, reviewerCount: reviewers.size, observedMean: mean, before, delta: score - before, after: score });
  }
  return { score, steps };
}
