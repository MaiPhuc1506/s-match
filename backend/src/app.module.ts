import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { PlayersModule } from './players/players.module';
import { AvailabilityPreferenceModule } from './availability-preference/availability-preference.module.js';
import { FacilitiesModule } from './facilities/facilities.module';
import { BookingsModule } from './bookings/bookings.module';
import { MatchesModule } from './matches/matches.module';
import { CandidatesModule } from './candidates/candidates.module';
import { MatchmakingModule } from './matchmaking.module';
import { RecommendationHistoryModule } from './recommendation-history/recommendation-history.module';
import { RatingsModule } from './ratings/ratings.module';
import { AnalyticsModule } from './analytics/analytics.module';
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    PlayersModule,
    AvailabilityPreferenceModule,
    FacilitiesModule,
    BookingsModule,
    MatchesModule,
    MatchmakingModule,
    CandidatesModule,
    RecommendationHistoryModule,
    RatingsModule,
    AnalyticsModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
