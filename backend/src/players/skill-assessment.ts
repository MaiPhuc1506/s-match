export const SKILL_AXES = ['smash', 'defense', 'netPlay', 'stamina', 'footwork', 'serve'] as const;

export function assessmentScore(skill?: Partial<Record<(typeof SKILL_AXES)[number], number>> | null): number | null {
  const values = SKILL_AXES.map((axis) => skill?.[axis]);
  if (!values.every((v): v is number => typeof v === 'number' && Number.isFinite(v) && v >= 1 && v <= 5)) return null;
  return values.reduce((sum, value) => sum + value, 0) / values.length;
}

// Existing recommendation buckets: levels 1–2, 3–4 and 5.
export function effectiveSkillLevel(score: number | null, fallback: string | null): string | null {
  return score === null ? fallback : score === 5 ? 'ADVANCED' : score >= 3 ? 'INTERMEDIATE' : 'BEGINNER';
}
