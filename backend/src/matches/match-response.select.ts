import { ParticipantStatus, Prisma } from '@prisma/client';

export const MATCH_PARTICIPANT_MUTATION_SELECT = {
  id: true, matchId: true, userId: true, role: true, status: true,
} satisfies Prisma.MatchParticipantSelect;

const MATCH_SUMMARY_SELECT = {
  id: true, title: true, description: true, privacy: true, status: true,
  mode: true, purpose: true, minSkillLevel: true, maxSkillLevel: true,
  hostId: true,
  host: { select: { id: true, fullName: true } },
  startTime: true, endTime: true, location: true, maxPlayers: true, feePerPlayer: true,
} satisfies Prisma.MatchSelect;

// Invitation previews omit booking, roster and participant count.
export const MATCH_INVITATION_SELECT = MATCH_SUMMARY_SELECT;

export const MATCH_PUBLIC_SELECT = {
  ...MATCH_SUMMARY_SELECT,
  booking: {
    select: {
      startTime: true, endTime: true, totalPrice: true,
      court: {
        select: {
          id: true, name: true, courtType: true,
          facility: {
            select: { id: true, name: true, address: true, latitude: true, longitude: true },
          },
        },
      },
    },
  },
  _count: { select: { participants: { where: { status: ParticipantStatus.ACCEPTED } } } },
} satisfies Prisma.MatchSelect;

const PARTICIPANT_SELECT = {
  id: true, userId: true, role: true, status: true,
  user: { select: { id: true, fullName: true } },
} satisfies Prisma.MatchParticipantSelect;

export const MATCH_MEMBER_SELECT = {
  ...MATCH_PUBLIC_SELECT,
  participants: { where: { status: ParticipantStatus.ACCEPTED }, select: PARTICIPANT_SELECT },
} satisfies Prisma.MatchSelect;

export const MATCH_MANAGER_SELECT = {
  ...MATCH_PUBLIC_SELECT,
  participants: { select: PARTICIPANT_SELECT },
} satisfies Prisma.MatchSelect;

// Do not expose Prisma's _count implementation detail.
export function toMatchResponse<T extends { _count?: { participants: number } }>(match: T) {
  const { _count, ...response } = match;
  return { ...response, participantCount: _count?.participants ?? 0 };
}
