import { AuthModule } from '../auth/auth.module';
import { RevenueAnalyticsController } from './revenue-analytics.controller';
import { RevenueAnalyticsService } from './revenue-analytics.service';
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AnalyticsController } from './analytics.controller';
import { PendingAnalyticsDataService } from './analytics-data.service';
import { AnalyticsService } from './analytics.service';
import { ANALYTICS_DATA_PROVIDER } from './interfaces/analytics-data-provider.interface';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [AnalyticsController, RevenueAnalyticsController],
  providers: [
    AnalyticsService,
    RevenueAnalyticsService,
    PendingAnalyticsDataService,
    { provide: ANALYTICS_DATA_PROVIDER, useExisting: PendingAnalyticsDataService },
  ],
  exports: [AnalyticsService, RevenueAnalyticsService, ANALYTICS_DATA_PROVIDER],
})
export class AnalyticsModule {}
