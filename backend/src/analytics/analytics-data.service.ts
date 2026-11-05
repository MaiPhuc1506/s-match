import { Injectable } from '@nestjs/common';
import {
  AnalyticsDataProvider,
  AnalyticsMetricValues,
  AnalyticsRange,
  AnalyticsScope,
  CourtMetricsResult,
} from './interfaces/analytics-data-provider.interface';
import { RevenueAnalyticsService } from './revenue-analytics.service';

/**
 * Unified AnalyticsDataProvider backed by RevenueAnalyticsService (SMM-38 + SMM-40).
 * Reuses Prisma/SQL aggregations without duplicating calculation logic.
 */
@Injectable()
export class AnalyticsDataService implements AnalyticsDataProvider {
  constructor(private readonly revenueAnalytics: RevenueAnalyticsService) {}

  getOverview(scope: AnalyticsScope, range: AnalyticsRange): Promise<AnalyticsMetricValues> {
    return this.revenueAnalytics.getOverviewForScope(scope, range);
  }

  getCourtMetrics(scope: AnalyticsScope, range: AnalyticsRange): Promise<CourtMetricsResult> {
    return this.revenueAnalytics.getCourtMetricsForScope(scope, range);
  }
}

export { AnalyticsDataService as PendingAnalyticsDataService };
