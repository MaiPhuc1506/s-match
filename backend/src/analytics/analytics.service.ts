import { BadRequestException, ForbiddenException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GetAnalyticsQueryDto } from './dto/get-analytics-query.dto';
import {
  AnalyticsOverviewResponseDto,
  CourtPerformanceListResponseDto,
} from './dto/analytics-response.dto';
import {
  ANALYTICS_DATA_PROVIDER,
  AnalyticsDataProvider,
  AnalyticsRange,
  AnalyticsScope,
} from './interfaces/analytics-data-provider.interface';

@Injectable()
export class AnalyticsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(ANALYTICS_DATA_PROVIDER) private readonly dataProvider: AnalyticsDataProvider,
  ) {}

  async getOwnerOverview(ownerId: number, query: GetAnalyticsQueryDto): Promise<AnalyticsOverviewResponseDto> {
    const scope = await this.resolveOwnerScope(ownerId, query.facilityId);
    return this.buildOverview(scope, query);
  }

  async getAdminOverview(query: GetAnalyticsQueryDto): Promise<AnalyticsOverviewResponseDto> {
    const scope = await this.resolveAdminScope(query.facilityId);
    return this.buildOverview(scope, query);
  }

  async getCourtPerformance(
    actor: { id: number; role: 'COURT_OWNER' | 'ADMIN' },
    query: GetAnalyticsQueryDto,
  ): Promise<CourtPerformanceListResponseDto> {
    const scope = actor.role === 'COURT_OWNER'
      ? await this.resolveOwnerScope(actor.id, query.facilityId)
      : await this.resolveAdminScope(query.facilityId);
    const range = this.toRange(query);
    const providerResult = await this.dataProvider.getCourtMetrics(scope, range);
    const metricsByCourt = new Map(providerResult.metrics.map((metric) => [metric.courtId, metric]));
    const courts = await this.prisma.court.findMany({
      where: scope.kind === 'OWNER'
        ? { facility: { ownerId: scope.ownerId }, ...(scope.facilityId !== undefined && { facilityId: scope.facilityId }) }
        : { ...(scope.facilityId !== undefined && { facilityId: scope.facilityId }) },
      select: { id: true, facilityId: true, name: true, status: true },
      orderBy: [{ facilityId: 'asc' }, { id: 'asc' }],
    });
    return {
      range: this.toResponseRange(range),
      dataStatus: providerResult.dataStatus,
      courts: courts.map((court) => {
        const metric = metricsByCourt.get(court.id);
        return {
          courtId: court.id,
          facilityId: court.facilityId,
          courtName: court.name,
          status: court.status,
          bookingCount: metric?.bookingCount ?? null,
          confirmedBookings: metric?.confirmedBookings ?? null,
          cancelledBookings: metric?.cancelledBookings ?? null,
          completedBookings: metric?.completedBookings ?? null,
          reservedHours: metric?.reservedHours ?? null,
          availableHours: metric?.availableHours ?? null,
          reservedOccupancyRatePercent: metric?.reservedOccupancyRatePercent ?? null,
          grossBookedRevenue: metric?.grossBookedRevenue ?? null,
        };
      }),
    };
  }

  private async buildOverview(scope: AnalyticsScope, query: GetAnalyticsQueryDto): Promise<AnalyticsOverviewResponseDto> {
    const range = this.toRange(query);
    const [metrics, totalFacilities] = await Promise.all([
      this.dataProvider.getOverview(scope, range),
      this.prisma.facility.count({
        where: scope.kind === 'OWNER'
          ? { ownerId: scope.ownerId, ...(scope.facilityId !== undefined && { id: scope.facilityId }) }
          : { ...(scope.facilityId !== undefined && { id: scope.facilityId }) },
      }),
    ]);
    return {
      scope: scope.kind,
      range: this.toResponseRange(range),
      dataStatus: metrics.dataStatus,
      summary: { totalFacilities, ...metrics },
    };
  }

  private async resolveOwnerScope(ownerId: number, facilityId?: number): Promise<AnalyticsScope> {
    if (facilityId === undefined) return { kind: 'OWNER', ownerId };
    const facility = await this.prisma.facility.findUnique({ where: { id: facilityId }, select: { ownerId: true } });
    if (!facility) throw new NotFoundException('Không tìm thấy cơ sở');
    if (facility.ownerId !== ownerId) throw new ForbiddenException('Bạn không có quyền xem thống kê cơ sở này');
    return { kind: 'OWNER', ownerId, facilityId };
  }

  private async resolveAdminScope(facilityId?: number): Promise<AnalyticsScope> {
    if (facilityId === undefined) return { kind: 'ADMIN' };
    const facility = await this.prisma.facility.findUnique({ where: { id: facilityId }, select: { id: true } });
    if (!facility) throw new NotFoundException('Không tìm thấy cơ sở');
    return { kind: 'ADMIN', facilityId };
  }

  private toRange(query: GetAnalyticsQueryDto): AnalyticsRange {
    const startDate = query.startDate === undefined ? null : new Date(query.startDate);
    const endDate = query.endDate === undefined ? null : new Date(query.endDate);
    if ((startDate && Number.isNaN(startDate.getTime())) || (endDate && Number.isNaN(endDate.getTime()))) {
      throw new BadRequestException('Khoảng thời gian không hợp lệ');
    }
    if (startDate && endDate && startDate >= endDate) {
      throw new BadRequestException('startDate phải trước endDate');
    }
    return { startDate, endDate };
  }

  private toResponseRange(range: AnalyticsRange) {
    return {
      startDate: range.startDate?.toISOString() ?? null,
      endDate: range.endDate?.toISOString() ?? null,
      timezone: 'UTC' as const,
    };
  }
}
