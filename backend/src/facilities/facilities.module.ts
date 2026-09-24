import { Module } from '@nestjs/common';
import { FacilitiesService } from './facilities.service';
import { FacilitiesController } from './facilities.controller';
import { OperatingHoursController } from './operating-hours.controller';
import { OperatingHoursService } from './operating-hours.service';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [FacilitiesController, OperatingHoursController],
  providers: [FacilitiesService, OperatingHoursService],
  exports: [FacilitiesService, OperatingHoursService],
})
export class FacilitiesModule {}