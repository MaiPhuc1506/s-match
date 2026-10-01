import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { TimeSlotsService } from './time-slots.service';
import { OperatingHoursService } from './operating-hours.service';
import { PrismaService } from '../prisma/prisma.service';

describe('TimeSlotsService', () => {
  let service: TimeSlotsService;
  let prisma: {
    timeSlot: {
      findMany: jest.Mock;
      findUnique: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
    court: { findUnique: jest.Mock };
    facility: { findUnique: jest.Mock };
  };
  let operatingHoursService: { isWithinOperatingHours: jest.Mock };

  const mockCourt = { id: 5, facilityId: 10 };
  const mockFacility = { id: 10, ownerId: 2 };

  beforeEach(async () => {
    prisma = {
      timeSlot: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
      court: { findUnique: jest.fn() },
      facility: { findUnique: jest.fn() },
    };
    operatingHoursService = { isWithinOperatingHours: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TimeSlotsService,
        { provide: PrismaService, useValue: prisma },
        { provide: OperatingHoursService, useValue: operatingHoursService },
      ],
    }).compile();

    service = module.get<TimeSlotsService>(TimeSlotsService);
  });

  describe('create', () => {
    const dto = { dayOfWeek: 1, startTime: '18:00', endTime: '19:00', price: 240000 };

    it('should throw ForbiddenException if user is not the facility owner', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);

      await expect(service.create(999, 10, 5, dto)).rejects.toThrow(ForbiddenException);
    });

    it('should throw NotFoundException if court does not belong to facility', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue({ id: 5, facilityId: 999 });

      await expect(service.create(2, 10, 5, dto)).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if startTime >= endTime', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);

      await expect(
        service.create(2, 10, 5, { ...dto, startTime: '19:00', endTime: '18:00' }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if slot is outside operating hours', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(false);

      await expect(service.create(2, 10, 5, dto)).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if slot overlaps an existing one', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(true);
      prisma.timeSlot.findMany.mockResolvedValue([
        { id: 1, startTime: '18:30', endTime: '19:30' },
      ]);

      await expect(service.create(2, 10, 5, dto)).rejects.toThrow(BadRequestException);
    });

    it('should create the time slot successfully', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(true);
      prisma.timeSlot.findMany.mockResolvedValue([]);
      prisma.timeSlot.create.mockResolvedValue({ id: 1, courtId: 5, ...dto });

      const result = await service.create(2, 10, 5, dto);
      expect(result.price).toBe(240000);
      expect(prisma.timeSlot.create).toHaveBeenCalled();
    });
  });

  describe('getAvailabilityForDate', () => {
    it('should return active slots for the resolved day of week', async () => {
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      prisma.timeSlot.findMany.mockResolvedValue([
        { id: 1, dayOfWeek: 1, startTime: '18:00', endTime: '19:00', price: 240000 },
      ]);

      const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
      expect(result).toHaveLength(1);
    });
  });

  describe('remove', () => {
    it('should throw NotFoundException if slot does not belong to court', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      prisma.timeSlot.findUnique.mockResolvedValue({ id: 1, courtId: 999 });

      await expect(service.remove(2, 10, 5, 1)).rejects.toThrow(NotFoundException);
    });

    it('should delete the time slot successfully', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      prisma.timeSlot.findUnique.mockResolvedValue({ id: 1, courtId: 5 });
      prisma.timeSlot.delete.mockResolvedValue({});

      const result = await service.remove(2, 10, 5, 1);
      expect(result).toEqual({ deleted: true });
    });
  });
});
