import { ForbiddenException } from '@nestjs/common';
import { MatchesService } from './matches.service';
import { PrismaService } from '../prisma/prisma.service';

const skill = (value: number) => ({ smash: value, defense: value, netPlay: value, stamina: value, footwork: value, serve: value });
describe('open match skill eligibility', () => {
  const tx = {
    $queryRaw: jest.fn(),
    match: { findUnique: jest.fn() },
    matchParticipant: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
    playerProfile: { findUnique: jest.fn() },
    matchNotification: { create: jest.fn() },
  };
  const prisma = { $transaction: jest.fn((action) => action(tx)) };
  const service = new MatchesService(prisma as unknown as PrismaService);
  const match = { id: 1, hostId: 2, status: 'OPEN', privacy: 'OPEN', startTime: new Date(Date.now() + 3600000), participants: [], maxPlayers: 4, minSkillLevel: 3, maxSkillLevel: 4 };
  beforeEach(() => {
    jest.clearAllMocks();
    tx.match.findUnique.mockResolvedValue(match);
    tx.matchParticipant.findUnique.mockResolvedValue(null);
    tx.matchParticipant.create.mockResolvedValue({ status: 'REQUESTED' });
    tx.matchNotification.create.mockResolvedValue({});
  });
  it.each([2.99, 4.01, null])('rejects out-of-range or unassessed skill %s', async (score) => {
    tx.playerProfile.findUnique.mockResolvedValue({ skill: score === null ? null : skill(score) });
    await expect(service.requestToJoin(1, 7)).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.matchParticipant.create).not.toHaveBeenCalled();
  });
  it.each([3, 4])('allows an exact boundary %s', async (score) => {
    tx.playerProfile.findUnique.mockResolvedValue({ skill: skill(score) });
    await expect(service.requestToJoin(1, 7)).resolves.toMatchObject({ status: 'REQUESTED' });
  });
  it('rejects an invalid pending request during host approval', async () => {
    tx.matchParticipant.findUnique.mockResolvedValue({ id: 9, status: 'REQUESTED' });
    tx.playerProfile.findUnique.mockResolvedValue({ skill: skill(2) });
    await expect(service.hostApproveRequest(1, 2, 7)).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.matchParticipant.update).not.toHaveBeenCalled();
  });
  it('rejects a score below 5 for a 5–5 match without rounding', async () => {
    tx.match.findUnique.mockResolvedValue({ ...match, minSkillLevel: 5, maxSkillLevel: 5 });
    tx.playerProfile.findUnique.mockResolvedValue({ skill: skill(4.99) });
    await expect(service.requestToJoin(1, 7)).rejects.toBeInstanceOf(ForbiddenException);
  });
  it('approves a pending request at the valid boundary', async () => {
    tx.matchParticipant.findUnique.mockResolvedValue({ id: 9, status: 'REQUESTED' });
    tx.playerProfile.findUnique.mockResolvedValue({ skill: skill(4) });
    tx.matchParticipant.update.mockResolvedValue({ status: 'ACCEPTED' });
    jest.spyOn(service as any, 'checkAndUpdateMatchFullState').mockResolvedValue(undefined);
    await expect(service.hostApproveRequest(1, 2, 7)).resolves.toMatchObject({ status: 'ACCEPTED' });
  });
  it('allows unassessed users in unrestricted 1–5 matches', async () => {
    tx.match.findUnique.mockResolvedValue({ ...match, minSkillLevel: 1, maxSkillLevel: 5 });
    await expect(service.requestToJoin(1, 7)).resolves.toMatchObject({ status: 'REQUESTED' });
  });
});
