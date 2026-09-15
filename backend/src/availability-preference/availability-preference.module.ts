import { Module } from '@nestjs/common';
import { AvailabilityController } from './availability.controller';
import { AvailabilityService } from './availability.service';
import { PreferenceController } from './preference.controller';
import { PreferenceService } from './preference.service';

// SMM-12 — Availability & Preference Backend.
@Module({
  controllers: [AvailabilityController, PreferenceController],
  providers: [AvailabilityService, PreferenceService],
  exports: [AvailabilityService, PreferenceService],
})
export class AvailabilityPreferenceModule {}
