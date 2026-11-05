import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { GetAnalyticsQueryDto } from './get-analytics-query.dto';

describe('GetAnalyticsQueryDto', () => {
  it('transforms a valid Facility ID query string to a PostgreSQL Int', async () => {
    const dto = plainToInstance(GetAnalyticsQueryDto, {
      facilityId: '2147483647',
      startDate: '2026-11-01T00:00:00.000Z',
      endDate: '2026-12-01T00:00:00.000Z',
    });
    expect(dto.facilityId).toBe(2147483647);
    expect(await validate(dto)).toHaveLength(0);
  });

  it.each(['0', '-1', '1.5', '2147483648', 'not-an-id'])('rejects invalid Facility ID %s', async (facilityId) => {
    const dto = plainToInstance(GetAnalyticsQueryDto, { facilityId });
    expect((await validate(dto)).some((error) => error.property === 'facilityId')).toBe(true);
  });

  it.each(['not-a-date', '2026-99-99T00:00:00.000Z'])('rejects invalid ISO date %s', async (startDate) => {
    const dto = plainToInstance(GetAnalyticsQueryDto, { startDate });
    expect((await validate(dto)).some((error) => error.property === 'startDate')).toBe(true);
  });
});
