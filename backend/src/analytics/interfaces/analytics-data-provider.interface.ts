export const ANALYTICS_DATA_PROVIDER = Symbol('ANALYTICS_DATA_PROVIDER');

export type AnalyticsScope =
  | { kind: 'OWNER'; ownerId: number; facilityId?: number }
  | { kind: 'ADMIN'; facilityId?: number };

export interface AnalyticsRange {
  startDate: Date | null;
  endDate: Date | null;
}

export interface AnalyticsMetricValues {
  dataStatus: 'PENDING_SMM_40' | 'READY';
  totalActiveUsers: number | null;
  totalBookings: number | null;
  bookingStatusBreakdown: {
    pending: number | null;
    confirmed: number | null;
    cancelled: number | null;
    completed: number | null;
  };
  reservedOccupancyRatePercent: number | null;
  grossBookedRevenue: number | null;
}

export interface CourtMetricValues {
  courtId: number;
  bookingCount: number | null;
  confirmedBookings: number | null;
  cancelledBookings: number | null;
  completedBookings: number | null;
  reservedHours: number | null;
  availableHours: number | null;
  reservedOccupancyRatePercent: number | null;
  grossBookedRevenue: number | null;
}

export interface CourtMetricsResult {
  dataStatus: 'PENDING_SMM_40' | 'READY';
  metrics: CourtMetricValues[];
}

export interface AnalyticsDataProvider {
  getOverview(scope: AnalyticsScope, range: AnalyticsRange): Promise<AnalyticsMetricValues>;
  getCourtMetrics(scope: AnalyticsScope, range: AnalyticsRange): Promise<CourtMetricsResult>;
}
