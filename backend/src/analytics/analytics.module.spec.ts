import { Test, TestingModule } from '@nestjs/testing';
import { PATH_METADATA } from '@nestjs/common/constants';
import { AnalyticsModule } from './analytics.module';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';
import { RevenueAnalyticsController } from './revenue-analytics.controller';
import { RevenueAnalyticsService } from './revenue-analytics.service';
import { PrismaService } from '../prisma/prisma.service';
import { AUTH_JWT_CONFIG } from '../auth/jwt.config';
import { ANALYTICS_DATA_PROVIDER } from './interfaces/analytics-data-provider.interface';
import { ROLES_KEY } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';

describe('AnalyticsModule — SMM-38 and SMM-40 coexistence', () => {
  let module: TestingModule;
  beforeAll(async () => {
    module = await Test.createTestingModule({ imports: [AnalyticsModule] })
      .overrideProvider(PrismaService).useValue({})
      .overrideProvider(AUTH_JWT_CONFIG).useValue({
        accessSecret: 'test-only-access-secret-not-used-for-requests',
        refreshSecret: 'test-only-refresh-secret-not-used-for-requests',
        issuer: 's-match-test', accessAudience: 'test', refreshAudience: 'test',
      }).compile();
  });
  afterAll(async () => { await module?.close(); });

  it('resolves both service constructors and retains the SMM-38 provider contract', () => {
    expect(module.get(AnalyticsService)).toBeInstanceOf(AnalyticsService);
    expect(module.get(RevenueAnalyticsService)).toBeInstanceOf(RevenueAnalyticsService);
    expect(module.get(ANALYTICS_DATA_PROVIDER)).toBeDefined();
    expect(module.get(AnalyticsController)).toBeDefined();
    expect(module.get(RevenueAnalyticsController)).toBeDefined();
  });

  it('keeps all six endpoint paths without replacing either API', () => {
    expect(Reflect.getMetadata(PATH_METADATA, AnalyticsController)).toBe('analytics');
    expect(Reflect.getMetadata(PATH_METADATA, RevenueAnalyticsController)).toBe('analytics/revenue');
    expect((['getOwnerOverview', 'getAdminOverview', 'getCourtPerformance'] as const).map(
      (name) => Reflect.getMetadata(PATH_METADATA, AnalyticsController.prototype[name]),
    )).toEqual(['owner/overview', 'admin/overview', 'courts/performance']);
    expect((['overview', 'trend', 'courtUtilization'] as const).map(
      (name) => Reflect.getMetadata(PATH_METADATA, RevenueAnalyticsController.prototype[name]),
    )).toEqual(['overview', 'trend', 'court-utilization']);
    expect(Reflect.getMetadata(ROLES_KEY, RevenueAnalyticsController)).toEqual([Role.OWNER, Role.ADMIN]);
    expect(Reflect.getMetadata(ROLES_KEY, AnalyticsController.prototype.getOwnerOverview)).toEqual([Role.OWNER]);
    expect(Reflect.getMetadata(ROLES_KEY, AnalyticsController.prototype.getAdminOverview)).toEqual([Role.ADMIN]);
  });

  it('passes the authenticated caller to the revenue service', () => {
    const service = module.get(RevenueAnalyticsService);
    const call = jest.spyOn(service, 'getOverview').mockResolvedValue({} as never);
    const query = { from: '2026-10-26', to: '2026-11-01', facilityId: 12 };
    module.get(RevenueAnalyticsController).overview({ user: { sub: 5, role: Role.OWNER } }, query);
    expect(call).toHaveBeenCalledWith({ userId: 5, role: Role.OWNER }, query);
  });
});
