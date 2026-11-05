import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { BookingStatus, CourtStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { Role } from '../auth/roles.enum';
import { AnalyticsQueryDto, RevenueTrendQueryDto } from './dto/analytics-query.dto';
import {
  availableHours,
  bookedHoursInRange,
  bookedHoursInWindow,
  DateRange,
  enumeratePeriods,
  percentRatio,
  periodKey,
  ratio,
  resolveDateRange,
  round,
  weekdayCounts,
  weekdayCountsForUtcInterval,
  weeklyOpenHours,
} from './analytics.util';
import {
  AnalyticsMetricValues,
  AnalyticsRange,
  AnalyticsScope,
  CourtMetricsResult,
} from './interfaces/analytics-data-provider.interface';

export const REVENUE_STATUSES: BookingStatus[] = [BookingStatus.CONFIRMED, BookingStatus.COMPLETED];

export interface AnalyticsCaller {
  userId: number;
  role: string;
}

interface CourtScope {
  id: number;
  name: string;
  status: CourtStatus;
  facilityId: number;
  facilityName: string;
  weeklyHours: number[];
}

interface Scope {
  isGlobal: boolean;
  facilityIds: number[];
  courts: CourtScope[];
}

const emptyStatusCounts = (): Record<BookingStatus, number> => ({
  PENDING: 0,
  CONFIRMED: 0,
  CANCELLED: 0,
  COMPLETED: 0,
});

@Injectable()
export class RevenueAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async getOverview(caller: AnalyticsCaller, query: AnalyticsQueryDto) {
    const range = resolveDateRange(query.from, query.to);
    const scope = await this.loadScope(caller, query.facilityId);

    const [bookings, statusCounts] = await Promise.all([
      this.fetchRevenueBookings(scope, range),
      this.countByStatus(scope, range),
    ]);

    let revenue = 0;
    let bookedHours = 0;
    for (const booking of bookings) {
      revenue += booking.totalPrice;
      bookedHours += bookedHoursInRange(booking.startTime, booking.endTime, range);
    }

    const counts = weekdayCounts(range);
    const capacity = scope.courts
      .filter((court) => court.status === CourtStatus.ACTIVE)
      .reduce((sum, court) => sum + availableHours(court.weeklyHours, counts), 0);

    const totalBookings = Object.values(statusCounts).reduce((sum, value) => sum + value, 0);
    const confirmedBookings = statusCounts.CONFIRMED + statusCounts.COMPLETED;

    return {
      range: { from: range.fromDate, to: range.toDate, days: range.days, timezone: 'Asia/Ho_Chi_Minh' },
      facilityId: query.facilityId ?? null,
      revenue: round(revenue),
      grossBookedRevenue: round(revenue),
      collectedRevenue: null,
      totalBookings,
      confirmedBookings,
      byStatus: statusCounts,
      cancellationRate: totalBookings > 0 ? round(statusCounts.CANCELLED / totalBookings, 4) : null,
      averageBookingValue: confirmedBookings > 0 ? round(revenue / confirmedBookings) : null,
      bookedHours: round(bookedHours),
      availableHours: round(capacity),
      occupancyRate: ratio(bookedHours, capacity),
    };
  }

  async getRevenueTrend(caller: AnalyticsCaller, query: RevenueTrendQueryDto) {
    const granularity = query.granularity ?? 'day';
    const range = resolveDateRange(query.from, query.to);
    const scope = await this.loadScope(caller, query.facilityId);
    const bookings = await this.fetchRevenueBookings(scope, range);

    const buckets = new Map(
      enumeratePeriods(range, granularity).map((key) => [
        key,
        { period: key, revenue: 0, bookingCount: 0, bookedHours: 0 },
      ]),
    );
    for (const booking of bookings) {
      const bucket = buckets.get(periodKey(booking.startTime, granularity));
      if (!bucket) continue;
      bucket.revenue += booking.totalPrice;
      bucket.bookingCount += 1;
      bucket.bookedHours += bookedHoursInRange(booking.startTime, booking.endTime, range);
    }

    const series = [...buckets.values()].map((bucket) => ({
      ...bucket,
      revenue: round(bucket.revenue),
      bookedHours: round(bucket.bookedHours),
    }));

    return {
      range: { from: range.fromDate, to: range.toDate, days: range.days, timezone: 'Asia/Ho_Chi_Minh' },
      granularity,
      facilityId: query.facilityId ?? null,
      totalRevenue: round(series.reduce((sum, point) => sum + point.revenue, 0)),
      totalBookings: series.reduce((sum, point) => sum + point.bookingCount, 0),
      series,
    };
  }

  async getCourtUtilization(caller: AnalyticsCaller, query: AnalyticsQueryDto) {
    const range = resolveDateRange(query.from, query.to);
    const scope = await this.loadScope(caller, query.facilityId);
    const bookings = await this.fetchRevenueBookings(scope, range);

    const perCourt = new Map<number, { bookingCount: number; revenue: number; bookedHours: number }>();
    for (const booking of bookings) {
      const entry = perCourt.get(booking.courtId) ?? { bookingCount: 0, revenue: 0, bookedHours: 0 };
      entry.bookingCount += 1;
      entry.revenue += booking.totalPrice;
      entry.bookedHours += bookedHoursInRange(booking.startTime, booking.endTime, range);
      perCourt.set(booking.courtId, entry);
    }

    const counts = weekdayCounts(range);
    const courts = scope.courts
      .map((court) => {
        const stats = perCourt.get(court.id) ?? { bookingCount: 0, revenue: 0, bookedHours: 0 };
        const capacity =
          court.status === CourtStatus.ACTIVE ? availableHours(court.weeklyHours, counts) : 0;
        return {
          courtId: court.id,
          courtName: court.name,
          status: court.status,
          facilityId: court.facilityId,
          facilityName: court.facilityName,
          bookingCount: stats.bookingCount,
          revenue: round(stats.revenue),
          bookedHours: round(stats.bookedHours),
          availableHours: round(capacity),
          utilizationRate: ratio(stats.bookedHours, capacity),
        };
      })
      .sort(
        (a, b) =>
          (b.utilizationRate ?? -1) - (a.utilizationRate ?? -1) ||
          b.revenue - a.revenue ||
          a.courtId - b.courtId,
      );

    return {
      range: { from: range.fromDate, to: range.toDate, days: range.days, timezone: 'Asia/Ho_Chi_Minh' },
      facilityId: query.facilityId ?? null,
      courts,
    };
  }

  async getOverviewForScope(scope: AnalyticsScope, range: AnalyticsRange): Promise<AnalyticsMetricValues> {
    const caller: AnalyticsCaller = {
      userId: scope.kind === 'OWNER' ? scope.ownerId : 0,
      role: scope.kind === 'ADMIN' ? Role.ADMIN : Role.OWNER,
    };
    const loadedScope = await this.loadScope(caller, scope.facilityId);
    const [bookings, statusCounts] = await Promise.all([
      this.fetchRevenueBookingsInWindow(loadedScope, range.startDate, range.endDate),
      this.countByStatusInWindow(loadedScope, range.startDate, range.endDate),
    ]);

    let grossBookedRevenue = 0;
    let reservedHours = 0;
    for (const booking of bookings) {
      grossBookedRevenue += booking.totalPrice;
      reservedHours += bookedHoursInWindow(booking.startTime, booking.endTime, range.startDate, range.endDate);
    }

    let reservedOccupancyRatePercent: number | null = null;
    if (range.startDate && range.endDate) {
      const counts = weekdayCountsForUtcInterval(range.startDate, range.endDate);
      const capacity = loadedScope.courts
        .filter((court) => court.status === CourtStatus.ACTIVE)
        .reduce((sum, court) => sum + availableHours(court.weeklyHours, counts), 0);
      reservedOccupancyRatePercent = percentRatio(reservedHours, capacity);
    }

    const totalBookings = Object.values(statusCounts).reduce((sum, value) => sum + value, 0);

    return {
      dataStatus: 'READY',
      totalActiveUsers: null,
      totalBookings,
      bookingStatusBreakdown: {
        pending: statusCounts.PENDING,
        confirmed: statusCounts.CONFIRMED,
        cancelled: statusCounts.CANCELLED,
        completed: statusCounts.COMPLETED,
      },
      reservedOccupancyRatePercent,
      grossBookedRevenue: round(grossBookedRevenue),
    };
  }

  async getCourtMetricsForScope(scope: AnalyticsScope, range: AnalyticsRange): Promise<CourtMetricsResult> {
    const caller: AnalyticsCaller = {
      userId: scope.kind === 'OWNER' ? scope.ownerId : 0,
      role: scope.kind === 'ADMIN' ? Role.ADMIN : Role.OWNER,
    };
    const loadedScope = await this.loadScope(caller, scope.facilityId);
    if (!loadedScope.isGlobal && loadedScope.courts.length === 0) {
      return { dataStatus: 'READY', metrics: [] };
    }

    const where = this.bookingWindowWhere(loadedScope, range.startDate, range.endDate);
    const [revenueBookings, groupedByCourtStatus] = await Promise.all([
      this.fetchRevenueBookingsInWindow(loadedScope, range.startDate, range.endDate),
      this.prisma.booking.groupBy({
        by: ['courtId', 'status'],
        where,
        _count: { _all: true },
      }),
    ]);

    const statusByCourt = new Map<number, Record<BookingStatus, number>>();
    for (const row of groupedByCourtStatus) {
      const counts = statusByCourt.get(row.courtId) ?? emptyStatusCounts();
      counts[row.status] = row._count._all;
      statusByCourt.set(row.courtId, counts);
    }

    const revByCourt = new Map<number, { revenue: number; reservedHours: number }>();
    for (const booking of revenueBookings) {
      const entry = revByCourt.get(booking.courtId) ?? { revenue: 0, reservedHours: 0 };
      entry.revenue += booking.totalPrice;
      entry.reservedHours += bookedHoursInWindow(booking.startTime, booking.endTime, range.startDate, range.endDate);
      revByCourt.set(booking.courtId, entry);
    }

    const counts =
      range.startDate && range.endDate
        ? weekdayCountsForUtcInterval(range.startDate, range.endDate)
        : null;

    const metrics = loadedScope.courts.map((court) => {
      const statusCounts = statusByCourt.get(court.id) ?? emptyStatusCounts();
      const revStats = revByCourt.get(court.id) ?? { revenue: 0, reservedHours: 0 };
      const bookingCount =
        statusCounts.PENDING + statusCounts.CONFIRMED + statusCounts.CANCELLED + statusCounts.COMPLETED;
      const capacity =
        counts !== null
          ? court.status === CourtStatus.ACTIVE
            ? availableHours(court.weeklyHours, counts)
            : 0
          : null;

      return {
        courtId: court.id,
        bookingCount,
        confirmedBookings: statusCounts.CONFIRMED,
        cancelledBookings: statusCounts.CANCELLED,
        completedBookings: statusCounts.COMPLETED,
        reservedHours: round(revStats.reservedHours),
        availableHours: capacity !== null ? round(capacity) : null,
        reservedOccupancyRatePercent:
          capacity !== null ? percentRatio(revStats.reservedHours, capacity) : null,
        grossBookedRevenue: round(revStats.revenue),
      };
    });

    return {
      dataStatus: 'READY',
      metrics,
    };
  }

  private async loadScope(caller: AnalyticsCaller, facilityId?: number): Promise<Scope> {
    const isAdmin = caller.role === Role.ADMIN;
    const where: Prisma.FacilityWhereInput = {
      ...(isAdmin ? {} : { ownerId: caller.userId }),
      ...(facilityId ? { id: facilityId } : {}),
    };

    const facilities = await this.prisma.facility.findMany({
      where,
      select: {
        id: true,
        name: true,
        operatingHours: { select: { dayOfWeek: true, openTime: true, closeTime: true } },
        courts: { select: { id: true, name: true, status: true }, orderBy: { id: 'asc' } },
      },
      orderBy: { id: 'asc' },
    });

    if (facilityId && facilities.length === 0) {
      if (isAdmin) throw new NotFoundException(`Không tìm thấy cơ sở ID ${facilityId}`);
      throw new ForbiddenException('Cơ sở không tồn tại hoặc bạn không có quyền xem thống kê của cơ sở này');
    }

    return {
      isGlobal: isAdmin && !facilityId,
      facilityIds: facilities.map((facility) => facility.id),
      courts: facilities.flatMap((facility) => {
        const weeklyHours = weeklyOpenHours(facility.operatingHours);
        return facility.courts.map((court) => ({
          id: court.id,
          name: court.name,
          status: court.status,
          facilityId: facility.id,
          facilityName: facility.name,
          weeklyHours,
        }));
      }),
    };
  }

  private bookingWindowWhere(
    scope: Scope,
    start: Date | null,
    end: Date | null,
  ): Prisma.BookingWhereInput {
    return {
      ...(start || end
        ? {
            startTime: {
              ...(start ? { gte: start } : {}),
              ...(end ? { lt: end } : {}),
            },
          }
        : {}),
      ...(scope.isGlobal ? {} : { courtId: { in: scope.courts.map((court) => court.id) } }),
    };
  }

  private bookingWhere(scope: Scope, range: DateRange): Prisma.BookingWhereInput {
    return this.bookingWindowWhere(scope, range.start, range.end);
  }

  private async fetchRevenueBookingsInWindow(scope: Scope, start: Date | null, end: Date | null) {
    if (!scope.isGlobal && scope.courts.length === 0) return [];
    return this.prisma.booking.findMany({
      where: { ...this.bookingWindowWhere(scope, start, end), status: { in: REVENUE_STATUSES } },
      select: { courtId: true, startTime: true, endTime: true, totalPrice: true },
    });
  }

  private async fetchRevenueBookings(scope: Scope, range: DateRange) {
    return this.fetchRevenueBookingsInWindow(scope, range.start, range.end);
  }

  private async countByStatusInWindow(scope: Scope, start: Date | null, end: Date | null) {
    const counts = emptyStatusCounts();
    if (!scope.isGlobal && scope.courts.length === 0) return counts;

    const grouped = await this.prisma.booking.groupBy({
      by: ['status'],
      where: this.bookingWindowWhere(scope, start, end),
      _count: { _all: true },
    });
    for (const row of grouped) counts[row.status] = row._count._all;
    return counts;
  }

  private async countByStatus(scope: Scope, range: DateRange) {
    return this.countByStatusInWindow(scope, range.start, range.end);
  }
}
