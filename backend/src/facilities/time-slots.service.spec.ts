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
    booking: { findMany: jest.Mock };
    facility: { findUnique: jest.Mock };
  };
  let operatingHoursService: { isWithinOperatingHours: jest.Mock; findAllForFacility: jest.Mock };

  const mockCourt = { id: 5, facilityId: 10, status: 'ACTIVE' };
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
      booking: { findMany: jest.fn().mockResolvedValue([]) },
      facility: { findUnique: jest.fn() },
    };
    operatingHoursService = {
      isWithinOperatingHours: jest.fn().mockResolvedValue(true),
      findAllForFacility: jest.fn().mockResolvedValue([]),
    };

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
        { id: 1, dayOfWeek: 1, startTime: '18:00', endTime: '19:00', price: 240000, isActive: true },
      ]);

      const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
      expect(result).toHaveLength(1);
    });
  });

  it('marks overlapping bookings but permits adjacent boundaries in Vietnam time', async () => {
    prisma.court.findUnique.mockResolvedValue(mockCourt);
    prisma.timeSlot.findMany.mockResolvedValue([
      { id: 1, startTime: '06:00', endTime: '07:00', price: 120000, isActive: true },
      { id: 2, startTime: '07:00', endTime: '08:00', price: 140000, isActive: true },
    ]);
    prisma.booking.findMany.mockResolvedValue([{ startTime: new Date('2026-10-04T23:00:00Z'), endTime: new Date('2026-10-05T00:00:00Z') }]);
    const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
    expect(result.map((s) => [s.price, s.isBooked])).toEqual([[120000, true], [140000, false]]);
  });

  it('preserves booked slots after closing as non-bookable, but omits unbooked ones', async () => {
    prisma.court.findUnique.mockResolvedValue(mockCourt);
    prisma.timeSlot.findMany.mockResolvedValue([
      { id: 1, startTime: '23:00', endTime: '24:00', isActive: true, price: 90000 },
      { id: 2, startTime: '22:00', endTime: '23:00', isActive: true, price: 90000 },
    ]);
    prisma.booking.findMany.mockResolvedValue([
      { startTime: new Date('2026-10-05T16:00:00Z'), endTime: new Date('2026-10-05T17:00:00Z') },
    ]);
    operatingHoursService.isWithinOperatingHours.mockResolvedValue(false);
    const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
    expect(result).toEqual([expect.objectContaining({ id: 1, isBooked: true, isActive: false })]);
  });

  it('returns booked and genuinely locked inactive slots', async () => {
    prisma.court.findUnique.mockResolvedValue(mockCourt);
    prisma.timeSlot.findMany.mockResolvedValue([
      { id: 1, startTime: '18:00', endTime: '19:00', isActive: false, price: 90000 },
      { id: 2, startTime: '19:00', endTime: '20:00', isActive: false, price: 90000 },
    ]);
    prisma.booking.findMany.mockResolvedValue([
      { startTime: new Date('2026-10-05T11:00:00Z'), endTime: new Date('2026-10-05T12:00:00Z') },
    ]);
    const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
    expect(result).toEqual([
      expect.objectContaining({ id: 1, isBooked: true, isActive: false, status: 'BOOKED' }),
      expect.objectContaining({ id: 2, isBooked: false, isActive: false, status: 'LOCKED' }),
    ]);
  });

  it('does not duplicate booked cells for superseded overlapping templates', async () => {
    prisma.court.findUnique.mockResolvedValue(mockCourt);
    prisma.timeSlot.findMany.mockResolvedValue([
      { id: 1, startTime: '18:00', endTime: '19:00', isActive: true, price: 90000 },
      { id: 2, startTime: '18:30', endTime: '19:30', isActive: false, price: 90000 },
    ]);
    prisma.booking.findMany.mockResolvedValue([
      { startTime: new Date('2026-10-05T11:00:00Z'), endTime: new Date('2026-10-05T12:00:00Z') },
    ]);
    const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
    expect(result).toEqual([expect.objectContaining({ id: 1, isBooked: true })]);
  });

  it('retains a historical booking when the overlapping active slot does not cover it', async () => {
    prisma.court.findUnique.mockResolvedValue(mockCourt);
    prisma.timeSlot.findMany.mockResolvedValue([
      { id: 1, startTime: '18:00', endTime: '18:30', isActive: true, price: 45000 },
      { id: 2, startTime: '18:00', endTime: '19:00', isActive: false, price: 90000 },
    ]);
    prisma.booking.findMany.mockResolvedValue([
      { startTime: new Date('2026-10-05T11:30:00Z'), endTime: new Date('2026-10-05T12:00:00Z') },
    ]);
    const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
    expect(result).toEqual([
      expect.objectContaining({ id: 1, status: 'AVAILABLE' }),
      expect.objectContaining({ id: 2, status: 'BOOKED', isActive: false }),
    ]);
  });

  it('returns a locked closing cell from the configured hours', async () => {
    prisma.court.findUnique.mockResolvedValue(mockCourt);
    prisma.timeSlot.findMany.mockResolvedValue([
      { id: 1, courtId: 5, dayOfWeek: 1, startTime: '22:00', endTime: '23:00', isActive: true, price: 90000 },
    ]);
    operatingHoursService.findAllForFacility.mockResolvedValue([{ dayOfWeek: 1, closeTime: '23:00' }]);
    const result = await service.getAvailabilityForDate(10, 5, '2026-10-05');
    expect(result).toEqual([
      expect.objectContaining({ id: 1, status: 'AVAILABLE' }),
      expect.objectContaining({ startTime: '23:00', endTime: '24:00', status: 'LOCKED', isActive: false }),
    ]);
  });

  it.each(['invalid', '2026-02-30', '2026-10-05T00:00:00Z', undefined])('rejects invalid availability date %s', async (date) => {
    await expect(service.getAvailabilityForDate(10, 5, date as string)).rejects.toThrow(BadRequestException);
  });

  it('does not offer maintenance courts', async () => {
    prisma.court.findUnique.mockResolvedValue({ ...mockCourt, status: 'MAINTENANCE' });
    expect(await service.getAvailabilityForDate(10, 5, '2026-10-05')).toEqual([]);
  });

  describe('update slot price', () => {
    it('rejects price changes by an owner of another facility', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      await expect(service.update(999, 10, 5, 1, { price: 90000 })).rejects.toThrow(ForbiddenException);
      expect(prisma.timeSlot.update).not.toHaveBeenCalled();
    });

    it('recalculates the hourly rate while retaining the walk-in charge', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      prisma.timeSlot.findUnique.mockResolvedValue({
        id: 1, courtId: 5, dayOfWeek: 1, startTime: '11:30', endTime: '12:00',
        price: 35000, hourlyRate: 70000, walkInPrice: 40000,
      });
      prisma.timeSlot.update.mockImplementation(({ data }) => data);
      const result = await service.update(2, 10, 5, 1, { price: 45000 });
      expect(result).toEqual({ price: 45000, hourlyRate: 90000 });
      expect(prisma.timeSlot.update).toHaveBeenCalledWith({
        where: { id: 1 }, data: { price: 45000, hourlyRate: 90000 },
      });
    });

    it('does not invent an hourly rate when none was published', async () => {
      prisma.facility.findUnique.mockResolvedValue(mockFacility);
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      prisma.timeSlot.findUnique.mockResolvedValue({
        id: 1, courtId: 5, dayOfWeek: 1, startTime: '18:00', endTime: '19:00',
        price: 80000, hourlyRate: null, walkInPrice: null,
      });
      prisma.timeSlot.update.mockImplementation(({ data }) => data);
      expect(await service.update(2, 10, 5, 1, { price: 90000 })).toEqual({ price: 90000 });
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
