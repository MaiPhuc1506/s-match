import { BadRequestException } from '@nestjs/common';
import { MatchPrivacy, MatchState, ParticipantStatus, Prisma } from '@prisma/client';
import { SKILL_AXES, assessmentScore } from './skill-assessment';
import { replaySkillAxis } from './skill-progression';

export async function replayPlayerSkill(tx: Prisma.TransactionClient, userId: number) {
  const profile = await tx.playerProfile.findUnique({ where: { userId }, include: { skill: true } });
  const skill = profile?.skill;
  if (!skill || assessmentScore(skill) === null) return;
  const initial = skill.initialScores as Record<string, number> | null;
  const baseline = initial ?? Object.fromEntries(SKILL_AXES.map(axis => [axis, skill[axis]]));
  if (assessmentScore(baseline) === null) throw new BadRequestException('Invalid skill baseline.');
  const ratings = await tx.playerRating.findMany({ where: { ratedUserId: userId, skillRatings: { not: Prisma.DbNull }, match: { status: MatchState.COMPLETED, privacy: MatchPrivacy.OPEN } },
    select: { id: true, matchId: true, raterId: true, skillRatings: true,
      match: { select: { startTime: true, participants: { where: { status: ParticipantStatus.ACCEPTED }, select: { userId: true } } } } } });
  const eligible = ratings.filter(r => r.raterId !== userId && r.match.participants.some(p => p.userId === userId) && r.match.participants.some(p => p.userId === r.raterId));
  const scores: Record<string, number> = {};
  const history: Record<string, unknown> = {};
  for (const axis of SKILL_AXES) {
    const evidence = eligible.flatMap(r => {
      const value = (r.skillRatings as Record<string, unknown> | null)?.[axis];
      return typeof value === 'number' && Number.isInteger(value) && value >= 1 && value <= 5
        ? [{ matchId: r.matchId, matchStartedAt: r.match.startTime, reviewerId: r.raterId, value }] : [];
    });
    const replay = replaySkillAxis(baseline[axis], evidence);
    scores[axis] = replay.score;
    history[axis] = { steps: replay.steps, ratingIds: eligible.filter(r => typeof (r.skillRatings as Record<string, unknown> | null)?.[axis] === 'number').map(r => r.id).sort((a,b) => a-b) };
  }
  await tx.skill.update({ where: { id: skill.id }, data: {
    smash: scores.smash, defense: scores.defense, netPlay: scores.netPlay, stamina: scores.stamina, footwork: scores.footwork, serve: scores.serve,
    ...(initial ? {} : { initialScores: baseline as Prisma.InputJsonObject, initialSource: 'LEGACY_BASELINE' }),
    progressHistory: { version: 1, axes: history } as Prisma.InputJsonObject,
  } });
}
