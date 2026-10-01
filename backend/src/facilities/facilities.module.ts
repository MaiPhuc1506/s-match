import { Module } from '@nestjs/common';
import { FacilitiesService } from './facilities.service';
import { FacilitiesController } from './facilities.controller';
import { OperatingHoursController } from './operating-hours.controller';
import { OperatingHoursService } from './operating-hours.service';
import { TimeSlotsController } from './time-slots.controller';
import { TimeSlotsService } from './time-slots.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [FacilitiesController, OperatingHoursController, TimeSlotsController],
  providers: [FacilitiesService, OperatingHoursService, TimeSlotsService],
  exports: [FacilitiesService, OperatingHoursService, TimeSlotsService],
})
export class FacilitiesModule {}