import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService, DEFAULT_HOURLY_PRICE } from './bookings.service';
import { PrismaService } from '../prisma/prisma.service';
import { OperatingHoursService } from '../facilities/operating-hours.service';
import { BookingStatus, CourtStatus } from '@prisma/client';

describe('BookingsService', () => {
  let service: BookingsService;
  let prisma: any;
  let operatingHoursService: any;

  const mockCourt = {
    id: 1,
    facilityId: 10,
    name: 'Sân 1',
    status: CourtStatus.ACTIVE,
    facility: {
      id: 10,
      ownerId: 2,
      name: 'Sunrise Badminton',
    },
  };

  beforeEach(async () => {
    prisma = {
      $transaction: jest.fn(async (cb) => cb(prisma)),
      $executeRaw: jest.fn().mockResolvedValue(1),
      court: {
        findUnique: jest.fn(),
      },
      booking: {
        create: jest.fn(),
        findFirst: jest.fn(),
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
      },
    };

    operatingHoursService = {
      isWithinOperatingHours: jest.fn().mockResolvedValue(true),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingsService,
        { provide: PrismaService, useValue: prisma },
        { provide: OperatingHoursService, useValue: operatingHoursService },
      ],
    }).compile();

    service = module.get<BookingsService>(BookingsService);
  });

  describe('create', () => {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 5);
    const dateStr = futureDate.toISOString().slice(0, 10);
    const validStartTime = `${dateStr}T08:00:00.000Z`;
    const validEndTime = `${dateStr}T10:00:00.000Z`;

    it('should throw BadRequestException if startTime is invalid', async () => {
      await expect(
        service.create(1, {
          courtId: 1,
          startTime: 'invalid-date',
          endTime: validEndTime,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if startTime >= endTime', async () => {
      await expect(
        service.create(1, {
          courtId: 1,
          startTime: validEndTime,
          endTime: validStartTime,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if startTime is in the past', async () => {
      await expect(
        service.create(1, {
          courtId: 1,
          startTime: '2020-01-01T08:00:00.000Z',
          endTime: '2020-01-01T10:00:00.000Z',
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if duration is under 30 minutes', async () => {
      const shortEnd = `${dateStr}T08:15:00.000Z`;
      await expect(
        service.create(1, {
          courtId: 1,
          startTime: validStartTime,
          endTime: shortEnd,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if booking spans multiple days', async () => {
      const nextDay = new Date(futureDate);
      nextDay.setDate(nextDay.getDate() + 1);
      const nextDateStr = nextDay.toISOString().slice(0, 10);

      await expect(
        service.create(1, {
          courtId: 1,
          startTime: `${dateStr}T23:00:00.000Z`,
          endTime: `${nextDateStr}T01:00:00.000Z`,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw NotFoundException if court does not exist', async () => {
      prisma.court.findUnique.mockResolvedValue(null);

      await expect(
        service.create(1, {
          courtId: 999,
          startTime: validStartTime,
          endTime: validEndTime,
        }),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw BadRequestException if court is MAINTENANCE or INACTIVE', async () => {
      prisma.court.findUnique.mockResolvedValue({
        ...mockCourt,
        status: CourtStatus.MAINTENANCE,
      });

      await expect(
        service.create(1, {
          courtId: 1,
          startTime: validStartTime,
          endTime: validEndTime,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if booking is outside operating hours', async () => {
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(false);

      await expect(
        service.create(1, {
          courtId: 1,
          startTime: validStartTime,
          endTime: validEndTime,
        }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw ConflictException if conflicting booking exists', async () => {
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(true);
      prisma.booking.findFirst.mockResolvedValue({
        id: 99,
        courtId: 1,
        status: BookingStatus.CONFIRMED,
      });

      await expect(
        service.create(1, {
          courtId: 1,
          startTime: validStartTime,
          endTime: validEndTime,
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('should successfully create booking with server-calculated price', async () => {
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(true);
      prisma.booking.findFirst.mockResolvedValue(null);

      const expectedPrice = Math.round(2 * DEFAULT_HOURLY_PRICE);
      const createdBooking = {
        id: 100,
        userId: 1,
        courtId: 1,
        startTime: new Date(validStartTime),
        endTime: new Date(validEndTime),
        totalPrice: expectedPrice,
        status: BookingStatus.CONFIRMED,
        court: mockCourt,
      };
      prisma.booking.create.mockResolvedValue(createdBooking);

      const result = await service.create(1, {
        courtId: 1,
        startTime: validStartTime,
        endTime: validEndTime,
        note: 'Test note',
      });

      expect(prisma.booking.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 1,
            courtId: 1,
            totalPrice: expectedPrice,
            status: BookingStatus.CONFIRMED,
          }),
        }),
      );
      expect(result).toEqual(createdBooking);
    });

    it('should handle concurrent requests: only one succeeds and the other fails with ConflictException', async () => {
      prisma.court.findUnique.mockResolvedValue(mockCourt);
      operatingHoursService.isWithinOperatingHours.mockResolvedValue(true);

      let existingBooking: any = null;
      let lockQueue = Promise.resolve();

      prisma.$transaction.mockImplementation(async (cb: any) => {
        const previousLock = lockQueue;
        let releaseLock: () => void;
        lockQueue = new Promise((resolve) => {
          releaseLock = resolve;
        });

        await previousLock;
        try {
          return await cb({
            $executeRaw: jest.fn().mockResolvedValue(1),
            court: { findUnique: jest.fn().mockResolvedValue(mockCourt) },
            booking: {
              findFirst: jest.fn().mockImplementation(async () => existingBooking),
              create: jest.fn().mockImplementation(async (args: any) => {
                existingBooking = { id: 101, ...args.data };
                return existingBooking;
              }),
            },
          });
        } finally {
          releaseLock!();
        }
      });

      const req1 = service.create(1, {
        courtId: 1,
        startTime: validStartTime,
        endTime: validEndTime,
      });

      const req2 = service.create(2, {
        courtId: 1,
        startTime: validStartTime,
        endTime: validEndTime,
      });

      const results = await Promise.allSettled([req1, req2]);

      const fulfilled = results.filter((r) => r.status === 'fulfilled');
      const rejected = results.filter((r) => r.status === 'rejected');

      expect(fulfilled).toHaveLength(1);
      expect(rejected).toHaveLength(1);

      const rejectedReason = (rejected[0] as PromiseRejectedResult).reason;
      expect(rejectedReason).toBeInstanceOf(ConflictException);
    });
  });

  describe('findMyBookings', () => {
    it('should return bookings for user', async () => {
      const mockList = [{ id: 1, userId: 5 }];
      prisma.booking.findMany.mockResolvedValue(mockList);

      const result = await service.findMyBookings(5);
      expect(prisma.booking.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { userId: 5 } }),
      );
      expect(result).toEqual(mockList);
    });
  });

  describe('findOne', () => {
    const booking = {
      id: 10,
      userId: 5,
      court: {
        facility: {
          ownerId: 2,
        },
      },
    };

    it('should throw NotFoundException if booking does not exist', async () => {
      prisma.booking.findUnique.mockResolvedValue(null);
      await expect(service.findOne(999, 5, 'PLAYER')).rejects.toThrow(NotFoundException);
    });

    it('should return booking if user is the booker', async () => {
      prisma.booking.findUnique.mockResolvedValue(booking);
      const res = await service.findOne(10, 5, 'PLAYER');
      expect(res).toEqual(booking);
    });

    it('should return booking if user is facility owner', async () => {
      prisma.booking.findUnique.mockResolvedValue(booking);
      const res = await service.findOne(10, 2, 'COURT_OWNER');
      expect(res).toEqual(booking);
    });

    it('should return booking if user is ADMIN', async () => {
      prisma.booking.findUnique.mockResolvedValue(booking);
      const res = await service.findOne(10, 99, 'ADMIN');
      expect(res).toEqual(booking);
    });

    it('should throw ForbiddenException if user is another player', async () => {
      prisma.booking.findUnique.mockResolvedValue(booking);
      await expect(service.findOne(10, 6, 'PLAYER')).rejects.toThrow(ForbiddenException);
    });
  });

  describe('cancel', () => {
    const activeBooking = {
      id: 10,
      userId: 5,
      status: BookingStatus.CONFIRMED,
      court: {
        facility: {
          ownerId: 2,
        },
      },
    };

    it('should throw NotFoundException if booking does not exist', async () => {
      prisma.booking.findUnique.mockResolvedValue(null);
      await expect(service.cancel(999, 5, 'PLAYER')).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException if requester is not authorized', async () => {
      prisma.booking.findUnique.mockResolvedValue(activeBooking);
      await expect(service.cancel(10, 999, 'PLAYER')).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if booking is already CANCELLED', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        ...activeBooking,
        status: BookingStatus.CANCELLED,
      });

      await expect(service.cancel(10, 5, 'PLAYER')).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if booking is COMPLETED', async () => {
      prisma.booking.findUnique.mockResolvedValue({
        ...activeBooking,
        status: BookingStatus.COMPLETED,
      });

      await expect(service.cancel(10, 5, 'PLAYER')).rejects.toThrow(BadRequestException);
    });

    it('should successfully cancel booking and update status to CANCELLED', async () => {
      prisma.booking.findUnique.mockResolvedValue(activeBooking);
      const updated = { ...activeBooking, status: BookingStatus.CANCELLED };
      prisma.booking.update.mockResolvedValue(updated);

      const result = await service.cancel(10, 5, 'PLAYER');
      expect(prisma.booking.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 10 },
          data: { status: BookingStatus.CANCELLED },
        }),
      );
      expect(result).toEqual(updated);
    });
  });
});
