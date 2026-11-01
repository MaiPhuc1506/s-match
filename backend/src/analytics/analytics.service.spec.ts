import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BookingStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '../auth/roles.enum';
import { AnalyticsService, REVENUE_STATUSES } from './analytics.service';

const RANGE = { from: '2026-10-26', to: '2026-11-01' }; // 7 ngày (Thứ 2 → Chủ nhật)

const allDaysOpen = [0, 1, 2, 3, 4, 5, 6].map((dayOfWeek) => ({
  dayOfWeek,
  openTime: '08:00',
  closeTime: '20:00',
}));

const facility = (overrides: Record<string, unknown> = {}) => ({
  id: 1,
  name: 'Sân S-Match',
  operatingHours: allDaysOpen,
  courts: [
    { id: 10, name: 'Sân 1', status: 'ACTIVE' },
    { id: 11, name: 'Sân 2', status: 'MAINTENANCE' },
  ],
  ...overrides,
});

const booking = (courtId: number, start: string, end: string, totalPrice: number) => ({
  courtId,
  startTime: new Date(start),
  endTime: new Date(end),
  totalPrice,
});

describe('AnalyticsService', () => {
  let service: AnalyticsService;
  let prisma: any;
  const owner = { userId: 5, role: Role.OWNER };
  const admin = { userId: 1, role: Role.ADMIN };

  beforeEach(async () => {
    prisma = {
      facility: { findMany: jest.fn().mockResolvedValue([facility()]) },
      booking: { findMany: jest.fn().mockResolvedValue([]), groupBy: jest.fn().mockResolvedValue([]) },
    };
    const module: TestingModule = await Test.createTestingModule({
      providers: [AnalyticsService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = module.get(AnalyticsService);
  });

  describe('scope & permissions', () => {
    it('limits an owner to their own facilities', async () => {
      await service.getOverview(owner, RANGE);
      expect(prisma.facility.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { ownerId: 5 } }),
      );
      const where = prisma.booking.findMany.mock.calls[0][0].where;
      expect(where.courtId).toEqual({ in: [10, 11] });
      expect(where.status).toEqual({ in: REVENUE_STATUSES });
    });

    it('lets an admin see everything without a courtId filter', async () => {
      await service.getOverview(admin, RANGE);
      expect(prisma.facility.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: {} }));
      const where = prisma.booking.findMany.mock.calls[0][0].where;
      expect(where.courtId).toBeUndefined();
      expect(prisma.booking.groupBy.mock.calls[0][0].where.courtId).toBeUndefined();
    });

    it('forbids an owner from reading a facility that is not theirs', async () => {
      prisma.facility.findMany.mockResolvedValue([]);
      await expect(service.getOverview(owner, { ...RANGE, facilityId: 99 })).rejects.toThrow(
        ForbiddenException,
      );
      expect(prisma.booking.findMany).not.toHaveBeenCalled();
    });

    it('returns 404 when an admin asks for a missing facility', async () => {
      prisma.facility.findMany.mockResolvedValue([]);
      await expect(service.getOverview(admin, { ...RANGE, facilityId: 99 })).rejects.toThrow(
        NotFoundException,
      );
    });

    it('returns zeros without hitting bookings when the owner has no courts', async () => {
      prisma.facility.findMany.mockResolvedValue([]);
      const result = await service.getOverview(owner, RANGE);
      expect(result).toMatchObject({ revenue: 0, totalBookings: 0, occupancyRate: null });
      expect(prisma.booking.findMany).not.toHaveBeenCalled();
      expect(prisma.booking.groupBy).not.toHaveBeenCalled();
    });
  });

  describe('getOverview', () => {
    it('computes revenue, booking counts, cancellation rate and occupancy', async () => {
      prisma.booking.findMany.mockResolvedValue([
        booking(10, '2026-10-27T01:00:00Z', '2026-10-27T03:00:00Z', 100000),
        booking(10, '2026-10-28T11:00:00Z', '2026-10-28T13:00:00Z', 200000),
      ]);
      prisma.booking.groupBy.mockResolvedValue([
        { status: BookingStatus.CONFIRMED, _count: { _all: 1 } },
        { status: BookingStatus.COMPLETED, _count: { _all: 1 } },
        { status: BookingStatus.CANCELLED, _count: { _all: 1 } },
      ]);

      const result = await service.getOverview(owner, RANGE);

      expect(result).toMatchObject({
        range: { from: '2026-10-26', to: '2026-11-01', days: 7 },
        revenue: 300000,
        totalBookings: 3,
        confirmedBookings: 2,
        byStatus: { PENDING: 0, CONFIRMED: 1, CANCELLED: 1, COMPLETED: 1 },
        cancellationRate: 0.3333,
        averageBookingValue: 150000,
        bookedHours: 4,
        availableHours: 84,
        occupancyRate: 0.0476,
      });
    });

    it('reports null rates when there is nothing to divide by', async () => {
      const result = await service.getOverview(owner, RANGE);
      expect(result).toMatchObject({
        revenue: 0,
        cancellationRate: null,
        averageBookingValue: null,
        occupancyRate: 0,
      });
    });

    it('has no occupancy when the facility has no operating hours', async () => {
      prisma.facility.findMany.mockResolvedValue([facility({ operatingHours: [] })]);
      const result = await service.getOverview(owner, RANGE);
      expect(result.availableHours).toBe(0);
      expect(result.occupancyRate).toBeNull();
    });

    it('rejects an invalid date range before querying', async () => {
      await expect(service.getOverview(owner, { from: '2026-11-02', to: '2026-11-01' })).rejects.toThrow();
      expect(prisma.facility.findMany).not.toHaveBeenCalled();
    });
  });

  describe('getRevenueTrend', () => {
    it('zero-fills every day and buckets by Vietnam-local date', async () => {
      prisma.booking.findMany.mockResolvedValue([
        booking(10, '2026-10-27T01:00:00Z', '2026-10-27T03:00:00Z', 100000),
        booking(10, '2026-10-31T18:00:00Z', '2026-10-31T20:00:00Z', 50000),
      ]);

      const result = await service.getRevenueTrend(owner, RANGE);

      expect(result.granularity).toBe('day');
      expect(result.series).toHaveLength(7);
      expect(result.series.find((p) => p.period === '2026-10-27')).toEqual({
        period: '2026-10-27',
        revenue: 100000,
        bookingCount: 1,
        bookedHours: 2,
      });
      expect(result.series.find((p) => p.period === '2026-11-01')).toMatchObject({
        revenue: 50000,
        bookingCount: 1,
      });
      expect(result.series.find((p) => p.period === '2026-10-29')).toMatchObject({
        revenue: 0,
        bookingCount: 0,
      });
      expect(result.totalRevenue).toBe(150000);
      expect(result.totalBookings).toBe(2);
    });

    it('supports weekly and monthly granularity', async () => {
      prisma.booking.findMany.mockResolvedValue([
        booking(10, '2026-10-27T01:00:00Z', '2026-10-27T03:00:00Z', 100000),
        booking(10, '2026-11-03T01:00:00Z', '2026-11-03T03:00:00Z', 70000),
      ]);

      const weekly = await service.getRevenueTrend(owner, {
        from: '2026-10-26',
        to: '2026-11-08',
        granularity: 'week',
      });
      expect(weekly.series.map((p) => [p.period, p.revenue])).toEqual([
        ['2026-10-26', 100000],
        ['2026-11-02', 70000],
      ]);

      const monthly = await service.getRevenueTrend(owner, {
        from: '2026-10-26',
        to: '2026-11-08',
        granularity: 'month',
      });
      expect(monthly.series.map((p) => [p.period, p.revenue])).toEqual([
        ['2026-10', 100000],
        ['2026-11', 70000],
      ]);
    });
  });

  describe('getCourtUtilization', () => {
    it('ranks courts by utilization and leaves inactive courts without a rate', async () => {
      prisma.facility.findMany.mockResolvedValue([
        facility({
          courts: [
            { id: 10, name: 'Sân 1', status: 'ACTIVE' },
            { id: 11, name: 'Sân 2', status: 'ACTIVE' },
            { id: 12, name: 'Sân 3', status: 'MAINTENANCE' },
          ],
        }),
      ]);
      prisma.booking.findMany.mockResolvedValue([
        booking(10, '2026-10-27T01:00:00Z', '2026-10-27T03:00:00Z', 100000),
        booking(11, '2026-10-27T01:00:00Z', '2026-10-27T09:00:00Z', 400000),
        booking(11, '2026-10-28T01:00:00Z', '2026-10-28T03:00:00Z', 100000),
      ]);

      const { courts } = await service.getCourtUtilization(owner, RANGE);

      expect(courts.map((c) => c.courtId)).toEqual([11, 10, 12]);
      expect(courts[0]).toMatchObject({
        courtName: 'Sân 2',
        facilityName: 'Sân S-Match',
        bookingCount: 2,
        revenue: 500000,
        bookedHours: 10,
        availableHours: 84,
        utilizationRate: 0.119,
      });
      expect(courts[2]).toMatchObject({
        status: 'MAINTENANCE',
        bookingCount: 0,
        availableHours: 0,
        utilizationRate: null,
      });
    });
  });
});
