import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '../prisma/prisma.module';
import { AvailabilityPreferenceModule } from '../availability-preference/availability-preference.module';
import { RatingsModule } from '../ratings/ratings.module';
import { CandidatesController } from './candidates.controller';
import { CandidatesService } from './candidates.service';

@Module({
  imports: [PrismaModule, JwtModule, AvailabilityPreferenceModule, RatingsModule],
  controllers: [CandidatesController],
  providers: [CandidatesService],
  exports: [CandidatesService],
})
export class CandidatesModule {}
