import { PlayersService } from './players.service';

describe('Google onboarding completion', () => {
  const db = { user: { update: jest.fn() }, googleIdentity: { updateMany: jest.fn() } };
  const prisma = { $transaction: jest.fn(async (fn) => fn(db)) };
  const service = new PlayersService(prisma as any);
  beforeEach(() => {
    jest.clearAllMocks();
    db.user.update.mockResolvedValue({ id: 7 });
    db.googleIdentity.updateMany.mockResolvedValue({ count: 1 });
  });
  it('completes only with both name and area in the profile transaction', async () => {
    await service.updateMyProfile(7, { fullName: 'Player', playingArea: 'Da Nang, Vietnam' });
    expect(db.user.update.mock.calls[0][0].data.playerProfile.upsert.update).toEqual({ playingArea: 'Da Nang, Vietnam' });
    expect(db.googleIdentity.updateMany).toHaveBeenCalledWith({ where: { userId: 7, onboardingPending: true }, data: { onboardingPending: false } });
  });
  it('does not complete on an unrelated or blank profile edit', async () => {
    await service.updateMyProfile(7, { fullName: 'Player', playingArea: '   ' });
    expect(db.googleIdentity.updateMany).not.toHaveBeenCalled();
  });
  it('completes explicit onboarding without requiring or overwriting playing area', async () => {
    await service.updateMyProfile(7, { fullName: 'Player', completeGoogleOnboarding: true });
    expect(db.user.update.mock.calls[0][0].data.playerProfile.upsert.update).toEqual({});
    expect(db.googleIdentity.updateMany).toHaveBeenCalledWith({ where: { userId: 7, onboardingPending: true }, data: { onboardingPending: false } });
  });
  it('does not complete if saving the profile fails', async () => {
    db.user.update.mockRejectedValueOnce(new Error('write failed'));
    await expect(service.updateMyProfile(7, { fullName: 'Player', playingArea: 'Da Nang' })).rejects.toThrow('write failed');
    expect(db.googleIdentity.updateMany).not.toHaveBeenCalled();
  });
});
