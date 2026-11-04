import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AnalyticsController } from './analytics.controller';
import { PendingAnalyticsDataService } from './analytics-data.service';
import { AnalyticsService } from './analytics.service';
import { ANALYTICS_DATA_PROVIDER } from './interfaces/analytics-data-provider.interface';

@Module({
  imports: [PrismaModule],
  controllers: [AnalyticsController],
  providers: [
    AnalyticsService,
    PendingAnalyticsDataService,
    { provide: ANALYTICS_DATA_PROVIDER, useExisting: PendingAnalyticsDataService },
  ],
  exports: [AnalyticsService, ANALYTICS_DATA_PROVIDER],
})
export class AnalyticsModule {}
