import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { OperatingHoursService } from './operating-hours.service';
import { PrismaService } from '../prisma/prisma.service';

describe('OperatingHoursService', () => {
  let service: OperatingHoursService;
  let prisma: {
    operatingHours: {
      findMany: jest.Mock;
      findUnique: jest.Mock;
      upsert: jest.Mock;
      delete: jest.Mock;
    };
    facility: {
      findUnique: jest.Mock;
    };
    $transaction: jest.Mock;
  };

  beforeEach(async () => {
    prisma = {
      operatingHours: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        upsert: jest.fn(),
        delete: jest.fn(),
      },
      facility: {
        findUnique: jest.fn(),
      },
      $transaction: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OperatingHoursService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<OperatingHoursService>(OperatingHoursService);
  });

  describe('findAllForFacility', () => {
    it('should return operating hours ordered by dayOfWeek', async () => {
      const mockHours = [
        { id: 1, facilityId: 10, dayOfWeek: 1, openTime: '06:00', closeTime: '22:00' },
      ];
      prisma.operatingHours.findMany.mockResolvedValue(mockHours);

      const result = await service.findAllForFacility(10);
      expect(result).toEqual(mockHours);
      expect(prisma.operatingHours.findMany).toHaveBeenCalledWith({
        where: { facilityId: 10 },
        orderBy: { dayOfWeek: 'asc' },
      });
    });
  });

  describe('upsertOne', () => {
    it('should throw BadRequestException if openTime >= closeTime', async () => {
      prisma.facility.findUnique.mockResolvedValue({ id: 10, ownerId: 2 });

      await expect(
        service.upsertOne(2, 10, { dayOfWeek: 1, openTime: '22:00', closeTime: '06:00' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ForbiddenException if user is not the owner', async () => {
      prisma.facility.findUnique.mockResolvedValue({ id: 10, ownerId: 2 });

      await expect(
        service.upsertOne(999, 10, { dayOfWeek: 1, openTime: '06:00', closeTime: '22:00' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should upsert operating hours successfully', async () => {
      prisma.facility.findUnique.mockResolvedValue({ id: 10, ownerId: 2 });
      prisma.operatingHours.upsert.mockResolvedValue({
        id: 1,
        facilityId: 10,
        dayOfWeek: 1,
        openTime: '06:00',
        closeTime: '22:00',
      });

      const result = await service.upsertOne(2, 10, {
        dayOfWeek: 1,
        openTime: '06:00',
        closeTime: '22:00',
      });

      expect(result.openTime).toBe('06:00');
      expect(prisma.operatingHours.upsert).toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('should throw NotFoundException if day does not exist', async () => {
      prisma.facility.findUnique.mockResolvedValue({ id: 10, ownerId: 2 });
      prisma.operatingHours.findUnique.mockResolvedValue(null);

      await expect(service.remove(2, 10, 1)).rejects.toThrow(NotFoundException);
    });

    it('should delete operating hour successfully', async () => {
      prisma.facility.findUnique.mockResolvedValue({ id: 10, ownerId: 2 });
      prisma.operatingHours.findUnique.mockResolvedValue({ id: 1, facilityId: 10, dayOfWeek: 1 });
      prisma.operatingHours.delete.mockResolvedValue({});

      const result = await service.remove(2, 10, 1);
      expect(result).toEqual({ deleted: true });
    });
  });

  describe('isWithinOperatingHours', () => {
    it('should return true if booking is within range', async () => {
      prisma.operatingHours.findUnique.mockResolvedValue({
        facilityId: 10,
        dayOfWeek: 1,
        openTime: '06:00',
        closeTime: '22:00',
      });

      const result = await service.isWithinOperatingHours(10, 1, '08:00', '10:00');
      expect(result).toBe(true);
    });

    it('should return false if booking is outside range', async () => {
      prisma.operatingHours.findUnique.mockResolvedValue({
        facilityId: 10,
        dayOfWeek: 1,
        openTime: '06:00',
        closeTime: '22:00',
      });

      const result = await service.isWithinOperatingHours(10, 1, '05:00', '07:00');
      expect(result).toBe(false);
    });
  });
});

