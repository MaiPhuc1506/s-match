import { Injectable } from '@nestjs/common';
import {
  AnalyticsDataProvider,
  AnalyticsMetricValues,
  AnalyticsRange,
  AnalyticsScope,
  CourtMetricsResult,
} from './interfaces/analytics-data-provider.interface';

/**
 * Temporary SMM-38 provider contract. It intentionally never fabricates metrics.
 * SMM-40 replaces this implementation with the reviewed Prisma/SQL aggregation.
 */
@Injectable()
export class PendingAnalyticsDataService implements AnalyticsDataProvider {
  async getOverview(_scope: AnalyticsScope, _range: AnalyticsRange): Promise<AnalyticsMetricValues> {
    return {
      dataStatus: 'PENDING_SMM_40',
      totalActiveUsers: null,
      totalBookings: null,
      bookingStatusBreakdown: { pending: null, confirmed: null, cancelled: null, completed: null },
      reservedOccupancyRatePercent: null,
      grossBookedRevenue: null,
    };
  }

  async getCourtMetrics(_scope: AnalyticsScope, _range: AnalyticsRange): Promise<CourtMetricsResult> {
    return { dataStatus: 'PENDING_SMM_40', metrics: [] };
  }
}
