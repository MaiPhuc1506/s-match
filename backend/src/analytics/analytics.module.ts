import { AuthModule } from '../auth/auth.module';
import { RevenueAnalyticsController } from './revenue-analytics.controller';
import { RevenueAnalyticsService } from './revenue-analytics.service';
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { AnalyticsController } from './analytics.controller';
import { AnalyticsDataService } from './analytics-data.service';
import { AnalyticsService } from './analytics.service';
import { ANALYTICS_DATA_PROVIDER } from './interfaces/analytics-data-provider.interface';

@Module({
  imports: [PrismaModule, AuthModule],
  controllers: [AnalyticsController, RevenueAnalyticsController],
  providers: [
    AnalyticsService,
    RevenueAnalyticsService,
    AnalyticsDataService,
    { provide: ANALYTICS_DATA_PROVIDER, useExisting: AnalyticsDataService },
  ],
  exports: [AnalyticsService, RevenueAnalyticsService, ANALYTICS_DATA_PROVIDER],
})
export class AnalyticsModule {}
