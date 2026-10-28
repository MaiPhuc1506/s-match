import { makeMatchBookingFixture } from './matches-booking.fixture';
import { projectMatch } from './matches-security.fixture';

// A serial transaction simulator, NOT proof of PostgreSQL row-lock behavior.
// It models commit/rollback so overlap tests cannot pass using a non-atomic mock.
export function makeMatchLifecycleFixture() {
  const fixture = makeMatchBookingFixture();
  const { prisma, rows } = fixture;
  const events: string[] = [];
  let tail = Promise.resolve();
  prisma.$transaction = jest.fn(async (action: (db: any) => Promise<any>) => {
    const previous = tail;
    let release!: () => void;
    tail = new Promise<void>((resolve) => { release = resolve; });
    await previous;
    const before = structuredClone(rows);
    events.push('begin');
    try {
      const result = await action(prisma);
      events.push('commit');
      return result;
    } catch (error) {
      for (const row of rows) Object.assign(row, before.find((old) => old.id === row.id));
      events.push('rollback');
      throw error;
    } finally {
      release();
    }
  });
  prisma.$queryRaw.mockImplementation(async (sql: TemplateStringsArray) => {
    events.push(sql.join('?').includes('"Match"') ? 'lock-match' : 'lock-booking');
    return [];
  });
  prisma.matchParticipant.create.mockImplementation(async ({ data, select }: any) => {
    const participant = { id: 999, ...data };
    rows.find((row) => row.id === data.matchId).participants.push(participant);
    return projectMatch(participant, select);
  });
  return { ...fixture, events };
}
