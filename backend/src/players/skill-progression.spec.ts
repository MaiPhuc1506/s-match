import { replaySkillAxis, SkillObservation } from './skill-progression';
const o = (matchId: number, reviewerId: number, value: number): SkillObservation => ({ matchId, reviewerId, value, matchStartedAt: new Date(Date.UTC(2026, 0, matchId)) });
describe('skill progression replay', () => {
  it('requires three matches and two reviewers before a bounded change', () => {
    expect(replaySkillAxis(3, [o(1, 1, 1), o(2, 2, 1)]).score).toBe(3);
    expect(replaySkillAxis(3, [o(1, 1, 1), o(2, 1, 1), o(3, 1, 1)]).score).toBe(3);
    expect(replaySkillAxis(3, [o(1, 1, 1), o(2, 2, 1), o(3, 1, 1)]).score).toBeCloseTo(2.9);
    expect(replaySkillAxis(3, [o(1, 1, 5), o(2, 2, 5), o(3, 1, 5)]).score).toBeCloseTo(3.1);
  });
  it('replays late feedback deterministically and adjusts at most once per match', () => {
    const evidence = [o(1, 1, 5), o(2, 2, 5), o(3, 1, 5), o(3, 2, 1)];
    const forward = replaySkillAxis(3, evidence), reverse = replaySkillAxis(3, [...evidence].reverse());
    expect(forward).toEqual(reverse);
    expect(forward.steps).toHaveLength(3);
    expect(Math.abs(forward.steps[2].delta)).toBeLessThanOrEqual(0.100000001);
    expect(replaySkillAxis(3, evidence)).toEqual(forward);
  });
  it('clamps scores and rejects invalid or duplicate evidence', () => {
    expect(replaySkillAxis(1, [o(1, 1, 1), o(2, 2, 1), o(3, 1, 1)]).score).toBe(1);
    expect(() => replaySkillAxis(3, [o(1, 1, 0)])).toThrow();
    expect(() => replaySkillAxis(3, [o(1, 1, 1), o(1, 1, 2)])).toThrow();
  });
});
