import { Prisma } from '@prisma/client';
import { makeMatchLifecycleFixture } from './matches-lifecycle.fixture';
import { projectMatch } from './matches-security.fixture';

// In-memory transaction simulator; never connects to PostgreSQL.
export function makeMatchFeedbackFixture() {
  const fixture = makeMatchLifecycleFixture();
  const feedbacks: any[] = [];
  fixture.privateMatch.status = 'COMPLETED';
  fixture.privateMatch.endTime = new Date(Date.now() - 1000);
  let sequence = 0;
  fixture.prisma.feedback = { create: jest.fn(async ({ data, select }: any) => {
    if (feedbacks.some((row) => ['matchId', 'senderUserId', 'recipientUserId'].every((key) => row[key] === data[key]))) {
      throw new Prisma.PrismaClientKnownRequestError('PRIVATE_DATABASE_ERROR', {
        code: 'P2002', clientVersion: '6.19.3',
        meta: { modelName: 'Feedback', target: ['matchId', 'senderUserId', 'recipientUserId'] },
      });
    }
    const row = { id: ++sequence, ...data, createdAt: new Date() };
    feedbacks.push(row);
    return projectMatch(row, select);
  }) };
  const transaction = fixture.prisma.$transaction.getMockImplementation()!;
  fixture.prisma.$transaction = jest.fn((action: (db: any) => Promise<any>, options: any) => transaction(async (db: any) => {
    const before = structuredClone(feedbacks);
    try { return await action(db); }
    catch (error) { feedbacks.splice(0, feedbacks.length, ...before); throw error; }
  }, options));
  return { ...fixture, feedbacks };
}
