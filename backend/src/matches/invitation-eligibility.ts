import { Prisma } from '@prisma/client';
import { haversineKm } from '../candidates/geo.util';
import { assessmentScore } from '../players/skill-assessment';

export const INVITATION_RADIUS_KM = 5;
export const invitationProfileSelect = {
  userId: true, latitude: true, longitude: true, skill: true,
  user: { select: { availabilities: { select: { dayOfWeek: true, startTime: true } } } },
} satisfies Prisma.PlayerProfileSelect;
type Profile = Prisma.PlayerProfileGetPayload<{ select: typeof invitationProfileSelect }>;

export const activeInvitationStatuses = ['ACCEPTED', 'REQUESTED', 'INVITED'];

function coordinate(value: number | null, bound: number): value is number {
  return value !== null && Number.isFinite(value) && Math.abs(value) <= bound;
}

export function eligibleNearbyInvite(host: Profile | null, target: Profile | null, min: number, max: number) {
  if (!host || !target || host.userId === target.userId) return false;
  if (!coordinate(host.latitude, 90) || !coordinate(host.longitude, 180) ||
      !coordinate(target.latitude, 90) || !coordinate(target.longitude, 180)) return false;
  if (haversineKm(host.latitude, host.longitude, target.latitude, target.longitude) > INVITATION_RADIUS_KM) return false;
  const score = assessmentScore(target.skill);
  if ((min !== 1 || max !== 5) && (score === null || score < min || score > max)) return false;
  const starts = new Set(host.user.availabilities.map((slot) => `${slot.dayOfWeek}/${slot.startTime}`));
  return target.user.availabilities.some((slot) => starts.has(`${slot.dayOfWeek}/${slot.startTime}`));
}
