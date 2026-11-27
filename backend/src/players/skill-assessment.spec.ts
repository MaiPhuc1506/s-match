import { assessmentScore, effectiveSkillLevel, SKILL_AXES } from './skill-assessment';

describe('persisted skill assessment', () => {
  const axes = Object.fromEntries(SKILL_AXES.map((axis, i) => [axis, i < 3 ? 2 : 3]));
  it('averages all six axes without rounding for comparisons and uses the existing integer buckets', () => {
    expect(assessmentScore(axes)).toBe(2.5);
    expect([2.5, 3, 4.9, 5].map((value) => effectiveSkillLevel(value, null)))
      .toEqual(['BEGINNER', 'INTERMEDIATE', 'INTERMEDIATE', 'ADVANCED']);
  });

  it('keeps legacy categories and leaves absent or invalid measurements unknown', () => {
    expect(assessmentScore(null)).toBeNull();
    expect(assessmentScore({ ...axes, footwork: 0 })).toBeNull();
    expect(assessmentScore({ ...axes, footwork: Number.NaN })).toBeNull();
    expect(effectiveSkillLevel(null, 'BEGINNER')).toBeNull();
    expect(effectiveSkillLevel(null, 'INTERMEDIATE')).toBe('INTERMEDIATE');
  });
});
