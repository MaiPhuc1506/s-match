import { ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { FacilitiesService } from './facilities.service';
import { PrismaService } from '../prisma/prisma.service';

describe('facility and court deletion safety', () => {
  const tx = {
    $queryRaw: jest.fn(),
    booking: { count: jest.fn() },
    timeSlot: { deleteMany: jest.fn() },
    court: { deleteMany: jest.fn(), delete: jest.fn() },
    operatingHours: { deleteMany: jest.fn() },
    facility: { delete: jest.fn() },
  };
  const prisma = { $transaction: jest.fn((fn) => fn(tx)) };
  const service = new FacilitiesService(prisma as unknown as PrismaService);
  beforeEach(() => { jest.clearAllMocks(); });
  it('rejects facility deletion when any booking history exists', async () => {
    tx.$queryRaw.mockResolvedValueOnce([{ id: 1, ownerId: 2, name: 'A' }]).mockResolvedValueOnce([{ id: 3 }]);
    tx.booking.count.mockResolvedValueOnce(1);
    await expect(service.deleteFacility(2, 1)).rejects.toBeInstanceOf(ConflictException);
    expect(tx.facility.delete).not.toHaveBeenCalled();
    expect(tx.court.deleteMany).not.toHaveBeenCalled();
  });
  it('rejects court deletion when any booking history exists', async () => {
    tx.$queryRaw.mockResolvedValueOnce([{ id: 1, ownerId: 2 }]).mockResolvedValueOnce([{ id: 3, name: 'C' }]);
    tx.booking.count.mockResolvedValueOnce(1);
    await expect(service.deleteCourt(2, 1, 3)).rejects.toBeInstanceOf(ConflictException);
    expect(tx.court.delete).not.toHaveBeenCalled();
  });
  it('rejects a different owner before touching children', async () => {
    tx.$queryRaw.mockResolvedValueOnce([{ id: 1, ownerId: 2 }]);
    await expect(service.deleteFacility(9, 1)).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.$queryRaw).toHaveBeenCalledTimes(1);
  });
  it('deletes an empty facility', async () => {
    tx.$queryRaw.mockResolvedValueOnce([{ id: 1, ownerId: 2, name: 'A' }]).mockResolvedValueOnce([]);
    await expect(service.deleteFacility(2, 1)).resolves.toBeDefined();
    expect(tx.facility.delete).toHaveBeenCalledWith({ where: { id: 1 } });
  });
  it('deletes a court without booking history', async () => {
    tx.$queryRaw.mockResolvedValueOnce([{ id: 1, ownerId: 2 }]).mockResolvedValueOnce([{ id: 3, name: 'C' }]);
    tx.booking.count.mockResolvedValueOnce(0);
    await expect(service.deleteCourt(2, 1, 3)).resolves.toBeDefined();
    expect(tx.court.delete).toHaveBeenCalledWith({ where: { id: 3 } });
  });
  it('rejects a missing facility', async () => {
    tx.$queryRaw.mockResolvedValueOnce([]);
    await expect(service.deleteCourt(2, 1, 3)).rejects.toBeInstanceOf(NotFoundException);
  });
});
