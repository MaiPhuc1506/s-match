import { PrismaService } from '../prisma/prisma.service';
import { UsersService } from './users.service';

describe('UsersService API projection (Prisma mock)', () => {
  const select = { id: true, fullName: true, role: { select: { name: true } } };
  const record = { id: 8, fullName: null, role: { name: 'PLAYER' } };
  let prisma: { user: { findMany: jest.Mock; findUnique: jest.Mock } };
  let service: UsersService;

  beforeEach(() => {
    prisma = { user: { findMany: jest.fn().mockResolvedValue([record]), findUnique: jest.fn().mockResolvedValue(record) } };
    service = new UsersService(prisma as unknown as PrismaService);
  });

  it('selects only the approved fields for the list', async () => {
    await expect(service.findAllForApi()).resolves.toEqual([record]);
    expect(prisma.user.findMany).toHaveBeenCalledWith({ select, orderBy: { createdAt: 'desc' } });
  });

  it('selects only the approved fields for a single user, including nullable fullName', async () => {
    await expect(service.findByIdForApi(8)).resolves.toEqual(record);
    expect(prisma.user.findUnique).toHaveBeenCalledWith({ where: { id: 8 }, select });
  });

  it('preserves missing-user results for controller handling', async () => {
    prisma.user.findUnique.mockResolvedValue(null);
    await expect(service.findByIdForApi(999)).resolves.toBeNull();
  });

  it('keeps the existing internal findById contract', async () => {
    await service.findById(8);
    expect(prisma.user.findUnique).toHaveBeenCalledWith({ where: { id: 8 }, include: { role: true } });
  });
});
