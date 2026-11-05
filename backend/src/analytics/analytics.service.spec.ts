import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { AnalyticsDataProvider } from './interfaces/analytics-data-provider.interface';

describe('AnalyticsService', () => {
  let prisma: any;
  let provider: jest.Mocked<AnalyticsDataProvider>;
  let service: AnalyticsService;

  beforeEach(() => {
    prisma = {
      facility: {
        findUnique: jest.fn(),
        count: jest.fn().mockResolvedValue(2),
      },
      court: { findMany: jest.fn().mockResolvedValue([]) },
    };
    provider = {
      getOverview: jest.fn().mockResolvedValue({
        dataStatus: 'PENDING_SMM_40', totalActiveUsers: null, totalBookings: null,
        bookingStatusBreakdown: { pending: null, confirmed: null, cancelled: null, completed: null },
        reservedOccupancyRatePercent: null, grossBookedRevenue: null,
      }),
      getCourtMetrics: jest.fn().mockResolvedValue({ dataStatus: 'PENDING_SMM_40', metrics: [] }),
    };
    service = new AnalyticsService(prisma, provider);
  });

  it('returns a truthful pending contract for an owner overview without a Facility filter', async () => {
    const result = await service.getOwnerOverview(10, { startDate: '2026-11-01T00:00:00.000Z', endDate: '2026-12-01T00:00:00.000Z' });
    expect(provider.getOverview).toHaveBeenCalledWith(
      { kind: 'OWNER', ownerId: 10 },
      { startDate: new Date('2026-11-01T00:00:00.000Z'), endDate: new Date('2026-12-01T00:00:00.000Z') },
    );
    expect(prisma.facility.count).toHaveBeenCalledWith({ where: { ownerId: 10 } });
    expect(result).toEqual(expect.objectContaining({ scope: 'OWNER', dataStatus: 'PENDING_SMM_40' }));
    expect(result.summary).toMatchObject({ totalFacilities: 2, totalBookings: null, grossBookedRevenue: null });
  });

  it('allows an owner to filter only a Facility it owns', async () => {
    prisma.facility.findUnique.mockResolvedValue({ ownerId: 10 });
    await service.getOwnerOverview(10, { facilityId: 12 });
    expect(provider.getOverview).toHaveBeenCalledWith({ kind: 'OWNER', ownerId: 10, facilityId: 12 }, expect.anything());
    expect(prisma.facility.count).toHaveBeenCalledWith({ where: { ownerId: 10, id: 12 } });
  });

  it('blocks cross-owner Facility analytics before provider or aggregate calls', async () => {
    prisma.facility.findUnique.mockResolvedValue({ ownerId: 20 });
    await expect(service.getOwnerOverview(10, { facilityId: 12 })).rejects.toBeInstanceOf(ForbiddenException);
    expect(provider.getOverview).not.toHaveBeenCalled();
    expect(prisma.facility.count).not.toHaveBeenCalled();
  });

  it('returns 404 for an unknown Owner Facility', async () => {
    prisma.facility.findUnique.mockResolvedValue(null);
    await expect(service.getOwnerOverview(10, { facilityId: 12 })).rejects.toBeInstanceOf(NotFoundException);
  });

  it('validates an Admin Facility filter and does not add an owner condition', async () => {
    prisma.facility.findUnique.mockResolvedValue({ id: 12 });
    await service.getAdminOverview({ facilityId: 12 });
    expect(provider.getOverview).toHaveBeenCalledWith({ kind: 'ADMIN', facilityId: 12 }, expect.anything());
    expect(prisma.facility.count).toHaveBeenCalledWith({ where: { id: 12 } });
  });

  it.each([
    [{ startDate: 'not-a-date' }],
    [{ startDate: '2026-12-01T00:00:00.000Z', endDate: '2026-11-01T00:00:00.000Z' }],
  ])('rejects an invalid range before accessing the provider', async (query) => {
    await expect(service.getAdminOverview(query)).rejects.toBeInstanceOf(BadRequestException);
    expect(provider.getOverview).not.toHaveBeenCalled();
  });

  it('limits owner Court Performance to courts joined through that owner facilities', async () => {
    prisma.court.findMany.mockResolvedValue([{ id: 4, facilityId: 12, name: 'Court 1', status: 'ACTIVE' }]);
    const result = await service.getCourtPerformance({ id: 10, role: 'COURT_OWNER' }, {});
    expect(prisma.court.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { facility: { ownerId: 10 } },
      select: { id: true, facilityId: true, name: true, status: true },
    }));
    expect(result).toMatchObject({ dataStatus: 'PENDING_SMM_40', courts: [{ courtId: 4, bookingCount: null }] });
  });

  it('maps only metrics returned for an accessible Court and never exposes provider extras', async () => {
    prisma.court.findMany.mockResolvedValue([{ id: 4, facilityId: 12, name: 'Court 1', status: 'ACTIVE' }]);
    provider.getCourtMetrics.mockResolvedValue({
      dataStatus: 'READY',
      metrics: [{
        courtId: 4, bookingCount: 3, confirmedBookings: 2, cancelledBookings: 1, completedBookings: 0,
        reservedHours: 4, availableHours: 10, reservedOccupancyRatePercent: 40, grossBookedRevenue: 320000,
      }],
    } as any);
    const result = await service.getCourtPerformance({ id: 1, role: 'ADMIN' }, {});
    expect(result.dataStatus).toBe('READY');
    expect(result.courts[0]).toEqual({
      courtId: 4, facilityId: 12, courtName: 'Court 1', status: 'ACTIVE', bookingCount: 3,
      confirmedBookings: 2, cancelledBookings: 1, completedBookings: 0, reservedHours: 4,
      availableHours: 10, reservedOccupancyRatePercent: 40, grossBookedRevenue: 320000,
    });
  });
});
