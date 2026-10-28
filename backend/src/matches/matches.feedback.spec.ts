import { Prisma } from '@prisma/client';
import { MatchesService } from './matches.service';
import { makeMatchFeedbackFixture } from '../../test/helpers/matches-feedback.fixture';

describe('SMM-34 Submit Feedback (Prisma mock)', () => {
  let fixture: ReturnType<typeof makeMatchFeedbackFixture>;
  let service: MatchesService;
  const dto = { recipientUserId: 30, rating: 5 };
  beforeEach(() => {
    fixture = makeMatchFeedbackFixture();
    service = new MatchesService(fixture.prisma);
  });
  function unchanged() {
    expect(fixture.prisma.match.update).not.toHaveBeenCalled();
    expect(fixture.prisma.match.updateMany).not.toHaveBeenCalled();
    expect(fixture.prisma.matchParticipant.update).not.toHaveBeenCalled();
    expect(fixture.prisma.matchParticipant.create).not.toHaveBeenCalled();
  }
  it.each([[10, 30], [30, 10]])('allows accepted host/member %s to rate %s with exact projection', async (sender, recipient) => {
    const before = structuredClone(fixture.rows);
    const response = await service.submitFeedback(11, sender, { recipientUserId: recipient, rating: 5 });
    expect(Object.keys(response).sort()).toEqual(['id', 'matchId', 'senderUserId', 'recipientUserId', 'rating', 'comment', 'createdAt'].sort());
    expect(response).toMatchObject({ matchId: 11, senderUserId: sender, recipientUserId: recipient, rating: 5, comment: null });
    expect(fixture.prisma.feedback.create.mock.calls[0][0].select).toEqual({ id: true, matchId: true, senderUserId: true, recipientUserId: true, rating: true, comment: true, createdAt: true });
    expect(fixture.rows).toEqual(before);
    expect(fixture.events).toEqual(['begin', 'lock-match', 'commit']);
    unchanged();
  });
  it.each(['OPEN', 'FULL', 'IN_PROGRESS', 'CANCELLED'])('rejects state %s before insert', async (status) => {
    fixture.privateMatch.status = status;
    await expect(service.submitFeedback(11, 10, dto)).rejects.toMatchObject({ status: 409 });
    expect(fixture.prisma.feedback.create).not.toHaveBeenCalled(); unchanged();
  });
  it('rejects a future endTime even if completed', async () => {
    fixture.privateMatch.endTime = new Date(Date.now() + 60000);
    await expect(service.submitFeedback(11, 10, dto)).rejects.toMatchObject({ status: 409 });
    expect(fixture.feedbacks).toHaveLength(0);
  });
  it('accepts server time exactly at endTime', async () => {
    jest.useFakeTimers();
    try {
      fixture.privateMatch.endTime = new Date();
      await expect(service.submitFeedback(11, 10, dto)).resolves.toMatchObject({ rating: 5 });
    } finally { jest.useRealTimers(); }
  });
  it.each([40, 50, 60, 70, 99])('rejects non-accepted sender %s', async (id) => {
    await expect(service.submitFeedback(11, id, dto)).rejects.toMatchObject({ status: 403 });
    expect(fixture.prisma.feedback.create).not.toHaveBeenCalled();
  });
  it.each([40, 50, 60, 70, 99])('rejects non-accepted recipient %s', async (id) => {
    await expect(service.submitFeedback(11, 10, { ...dto, recipientUserId: id })).rejects.toMatchObject({ status: 400 });
    expect(fixture.prisma.feedback.create).not.toHaveBeenCalled();
  });
  it('does not treat hostId alone as proof of participation', async () => {
    fixture.privateMatch.participants = fixture.privateMatch.participants.filter((p: any) => p.userId !== 10);
    await expect(service.submitFeedback(11, 10, dto)).rejects.toMatchObject({ status: 403 });
  });
  it('drops unexpected relations even if the database mock ignores select', async () => {
    fixture.prisma.feedback.create.mockResolvedValueOnce({
      id: 1, matchId: 11, senderUserId: 10, recipientUserId: 30,
      rating: 5, comment: null, createdAt: new Date(),
      sender: { email: 'PRIVATE_EMAIL', password: 'PRIVATE_PASSWORD' },
      match: { booking: { note: 'PRIVATE_NOTE' } }, internalMetadata: 'PRIVATE_METADATA',
    });
    const response = await service.submitFeedback(11, 10, dto);
    expect(Object.keys(response)).toHaveLength(7);
    expect(JSON.stringify(response)).not.toContain('PRIVATE_');
  });
  it('allows independent recipients and opposite-direction feedback', async () => {
    fixture.privateMatch.participants.find((p: any) => p.userId === 40)!.status = 'ACCEPTED';
    await service.submitFeedback(11, 10, dto);
    await service.submitFeedback(11, 10, { ...dto, recipientUserId: 40 });
    await service.submitFeedback(11, 30, { ...dto, recipientUserId: 10 });
    expect(fixture.feedbacks).toHaveLength(3);
  });
  it('returns 404 for an absent Match', async () => {
    await expect(service.submitFeedback(999, 10, dto)).rejects.toMatchObject({ status: 404 });
  });
  it('rejects self feedback before transaction', async () => {
    await expect(service.submitFeedback(11, 30, dto)).rejects.toMatchObject({ status: 400 });
    expect(fixture.prisma.$transaction).not.toHaveBeenCalled();
  });
  it.each([0, -1, 1.5, 2147483648, null, '30'])('rejects recipient ID %s', async (id) => {
    await expect(service.submitFeedback(11, 10, { ...dto, recipientUserId: id as any })).rejects.toMatchObject({ status: 400 });
    expect(fixture.prisma.$transaction).not.toHaveBeenCalled();
  });
  it.each([0, 6, 1.5, null, '5'])('rejects rating %s', async (rating) => {
    await expect(service.submitFeedback(11, 10, { ...dto, rating: rating as any })).rejects.toMatchObject({ status: 400 });
    expect(fixture.feedbacks).toHaveLength(0);
  });
  it.each([null, 123, 'a'.repeat(501)])('rejects invalid comment', async (comment) => {
    await expect(service.submitFeedback(11, 10, { ...dto, comment: comment as any })).rejects.toMatchObject({ status: 400 });
    expect(fixture.feedbacks).toHaveLength(0);
  });
  it.each(['', 'a'.repeat(500), '😀'.repeat(500)])('preserves valid comments', async (comment) => {
    await expect(service.submitFeedback(11, 10, { ...dto, comment })).resolves.toMatchObject({ comment });
  });
  it('maps duplicate to 409 and preserves the original feedback', async () => {
    await service.submitFeedback(11, 10, dto);
    await expect(service.submitFeedback(11, 10, dto)).rejects.toMatchObject({ status: 409 });
    expect(fixture.feedbacks).toHaveLength(1);
  });
  it('allows only one of two concurrent duplicates (simulated transaction)', async () => {
    const results = await Promise.allSettled([service.submitFeedback(11, 10, dto), service.submitFeedback(11, 10, dto)]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    expect(results.find((r) => r.status === 'rejected')).toMatchObject({ reason: { status: 409 } });
    expect(fixture.feedbacks).toHaveLength(1);
  });
  it.each([
    ['P2002', { target: ['bookingId'] }, 500],
    ['P2002', { modelName: 'Other', target: ['matchId', 'senderUserId', 'recipientUserId'] }, 500],
    ['P2002', { target: 'Feedback_matchId_senderUserId_recipientUserId_key' }, 409],
    ['P2003', {}, 500], ['P2034', {}, 409],
  ])('sanitizes %s with target-specific duplicate handling', async (code, meta, status) => {
    fixture.prisma.feedback.create.mockRejectedValueOnce(new Prisma.PrismaClientKnownRequestError('PRIVATE_DATABASE_ERROR', { code, clientVersion: '6.19.3', meta }));
    await expect(service.submitFeedback(11, 10, dto)).rejects.toMatchObject({ status });
    expect(fixture.feedbacks).toHaveLength(0);
  });
  it('rolls back a failed insert without changing Match or participants', async () => {
    const before = structuredClone(fixture.rows);
    fixture.prisma.feedback.create.mockImplementationOnce(async () => {
      fixture.feedbacks.push({ id: 1 });
      throw new Error('PRIVATE_DATABASE_ERROR');
    });
    await expect(service.submitFeedback(11, 10, dto)).rejects.toMatchObject({ status: 500, message: expect.not.stringContaining('PRIVATE_') });
    expect(fixture.feedbacks).toHaveLength(0);
    expect(fixture.rows).toEqual(before);
    expect(fixture.events).toContain('rollback'); unchanged();
  });
});
