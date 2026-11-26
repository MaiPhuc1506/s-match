import { PlayersService } from './players.service';

describe('initial skill estimate', () => {
  const prisma: any = { playerProfile: { upsert: jest.fn(), findUnique: jest.fn() }, skill: { create: jest.fn(), update: jest.fn(), findUniqueOrThrow: jest.fn() }, playerRating: { findMany: jest.fn() }, $queryRaw: jest.fn(), $transaction: jest.fn() };
  const service = new PlayersService(prisma as any);
  beforeEach(() => {
    jest.resetAllMocks();
    prisma.playerProfile.upsert.mockResolvedValue({ id: 12 });
    prisma.$transaction.mockImplementation(async (cb: (tx: any) => Promise<unknown>) => cb(prisma));
    prisma.playerProfile.findUnique.mockResolvedValue(null);
    prisma.skill.create.mockImplementation(async ({ data }: { data: unknown }) => data);
    prisma.skill.findUniqueOrThrow.mockImplementation(async () => prisma.skill.create.mock.results[0].value);
  });
  it('maps six answer choices to six server-side axes', async () => {
    const result = await service.submitInitialSkill(41, [0, 1, 2, 3, 4, 0]);
    expect(result.kind).toBe('INITIAL_ESTIMATE');
    expect(result.skill).toMatchObject({ playerProfileId: 12, smash: 1, defense: 2, netPlay: 3, stamina: 4, footwork: 5, serve: 1 });
    expect(result.overallSkillScore).toBeCloseTo(16 / 6);
  });
  it.each([[0, 1], [0, 0, 0, 0, 0, 5], [0, 0, 0, 0, 0, 1.2]])('rejects malformed answers', async (...answers) => {
    await expect(service.submitInitialSkill(41, answers)).rejects.toMatchObject({ status: 400 });
    expect(prisma.skill.create).not.toHaveBeenCalled();
  });
  it('does not overwrite an existing assessment even on a concurrent submit', async () => {
    prisma.skill.create.mockRejectedValue({ code: 'P2002' });
    await expect(service.submitInitialSkill(41, [0, 0, 0, 0, 0, 0])).rejects.toMatchObject({ status: 409 });
  });
});
