import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { BookingStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '../auth/roles.enum';
import { RevenueAnalyticsService, REVENUE_STATUSES } from './revenue-analytics.service';

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

describe('RevenueAnalyticsService', () => {
  let service: RevenueAnalyticsService;
  let prisma: any;
  const owner = { userId: 5, role: Role.OWNER };
  const admin = { userId: 1, role: Role.ADMIN };

  beforeEach(async () => {
    prisma = {
      facility: { findMany: jest.fn().mockResolvedValue([facility()]) },
      booking: { findMany: jest.fn().mockResolvedValue([]), groupBy: jest.fn().mockResolvedValue([]) },
    };
    const module: TestingModule = await Test.createTestingModule({
      providers: [RevenueAnalyticsService, { provide: PrismaService, useValue: prisma }],
    }).compile();
    service = module.get(RevenueAnalyticsService);
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
        grossBookedRevenue: 300000,
        collectedRevenue: null,
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
        grossBookedRevenue: 0,
        collectedRevenue: null,
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

  describe('SMM-38 unified provider methods (getOverviewForScope & getCourtMetricsForScope)', () => {
    it('computes overview metrics for bounded and unbounded ranges without fabricating unavailable metrics', async () => {
      prisma.booking.findMany.mockResolvedValue([
        booking(10, '2026-10-27T01:00:00Z', '2026-10-27T03:00:00Z', 100000),
      ]);
      prisma.booking.groupBy.mockResolvedValue([
        { status: BookingStatus.CONFIRMED, _count: { _all: 1 } },
        { status: BookingStatus.PENDING, _count: { _all: 2 } },
      ]);

      const bounded = await service.getOverviewForScope(
        { kind: 'OWNER', ownerId: 5 },
        { startDate: new Date('2026-10-26T00:00:00Z'), endDate: new Date('2026-11-02T00:00:00Z') },
      );
      expect(bounded).toEqual({
        dataStatus: 'READY',
        totalActiveUsers: null,
        totalBookings: 3,
        bookingStatusBreakdown: { pending: 2, confirmed: 1, cancelled: 0, completed: 0 },
        reservedOccupancyRatePercent: 2.38,
        grossBookedRevenue: 100000,
      });

      const unbounded = await service.getOverviewForScope({ kind: 'ADMIN' }, { startDate: null, endDate: null });
      expect(unbounded.reservedOccupancyRatePercent).toBeNull();
      expect(unbounded.totalActiveUsers).toBeNull();
      expect(unbounded.grossBookedRevenue).toBe(100000);
    });

    it('computes per-court metrics including status breakdown and occupancy when bounded', async () => {
      prisma.booking.findMany.mockResolvedValue([
        booking(10, '2026-10-27T01:00:00Z', '2026-10-27T05:00:00Z', 240000),
      ]);
      prisma.booking.groupBy.mockResolvedValue([
        { courtId: 10, status: BookingStatus.CONFIRMED, _count: { _all: 1 } },
        { courtId: 10, status: BookingStatus.CANCELLED, _count: { _all: 1 } },
      ]);

      const res = await service.getCourtMetricsForScope(
        { kind: 'OWNER', ownerId: 5 },
        { startDate: new Date('2026-10-26T00:00:00Z'), endDate: new Date('2026-11-02T00:00:00Z') },
      );

      expect(res.dataStatus).toBe('READY');
      expect(res.metrics).toEqual([
        {
          courtId: 10,
          bookingCount: 2,
          confirmedBookings: 1,
          cancelledBookings: 1,
          completedBookings: 0,
          reservedHours: 4,
          availableHours: 84,
          reservedOccupancyRatePercent: 4.76,
          grossBookedRevenue: 240000,
        },
        {
          courtId: 11,
          bookingCount: 0,
          confirmedBookings: 0,
          cancelledBookings: 0,
          completedBookings: 0,
          reservedHours: 0,
          availableHours: 0,
          reservedOccupancyRatePercent: null,
          grossBookedRevenue: 0,
        },
      ]);
    });
  });
});
