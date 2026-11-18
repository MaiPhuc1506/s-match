import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AuthTokensService } from '../auth/auth-tokens.service';
import { PrismaService } from '../prisma/prisma.service';
import { TimeSlotsController } from './time-slots.controller';
import { TimeSlotsService } from './time-slots.service';

describe('owner slot pricing endpoint', () => {
  let app: INestApplication;
  const update = jest.fn();
  const path = '/facilities/45/courts/51/time-slots/80/pricing';

  beforeAll(async () => {
    const module = await Test.createTestingModule({
      controllers: [TimeSlotsController],
      providers: [
        { provide: TimeSlotsService, useValue: { update } },
        { provide: AuthTokensService, useValue: { verify: async (token: string) => ({ sub: 1, sid: token }) } },
        { provide: PrismaService, useValue: { refreshSession: {
          findUnique: async ({ where }: { where: { id: string } }) => ({
            userId: 1, expiresAt: new Date(Date.now() + 60000), revokedAt: null,
            user: { id: 1, email: 'test@example.test', role: {
              name: where.id === 'owner' ? 'COURT_OWNER' : 'PLAYER',
            } },
          }),
        } } },
      ],
    }).compile();
    app = module.createNestApplication();
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: true }));
    await app.init();
  });

  beforeEach(() => update.mockReset().mockResolvedValue({ id: 80, price: 90000 }));
  afterAll(async () => { await app.close(); });

  it('allows an owner to update only the full-slot price', async () => {
    await request(app.getHttpServer()).patch(path).auth('owner', { type: 'bearer' })
      .send({ price: 90000 }).expect(200);
    expect(update).toHaveBeenCalledWith(1, 45, 51, 80, { price: 90000 }, 'COURT_OWNER');
  });

  it('rejects players, invalid prices and unexpected fields', async () => {
    await request(app.getHttpServer()).patch(path).auth('player', { type: 'bearer' })
      .send({ price: 90000 }).expect(403);
    await request(app.getHttpServer()).patch(path).auth('owner', { type: 'bearer' })
      .send({ price: -1 }).expect(400);
    await request(app.getHttpServer()).patch(path).auth('owner', { type: 'bearer' })
      .send({ price: 90000, walkInPrice: 0 }).expect(400);
    expect(update).not.toHaveBeenCalled();
  });
});
