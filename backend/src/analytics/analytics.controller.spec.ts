import { AnalyticsController } from './analytics.controller';
import { AnalyticsService } from './analytics.service';

describe('AnalyticsController', () => {
  const service = {
    getOwnerOverview: jest.fn(),
    getAdminOverview: jest.fn(),
    getCourtPerformance: jest.fn(),
  } as unknown as jest.Mocked<AnalyticsService>;
  const controller = new AnalyticsController(service);

  beforeEach(() => jest.clearAllMocks());

  it('takes Owner identity exclusively from the authenticated request', () => {
    const query = { facilityId: 12 };
    controller.getOwnerOverview({ user: { sub: 10 } }, query);
    expect(service.getOwnerOverview).toHaveBeenCalledWith(10, query);
  });

  it('does not accept an Owner identity in the query for Court Performance', () => {
    const query = { facilityId: 12 };
    controller.getCourtPerformance({ user: { sub: 10, role: 'COURT_OWNER' } }, query);
    expect(service.getCourtPerformance).toHaveBeenCalledWith({ id: 10, role: 'COURT_OWNER' }, query);
  });
});
