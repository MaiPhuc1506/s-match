import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  BulkUpsertOperatingHoursDto,
  UpsertOperatingHourDto,
} from './dto/operating-hours.dto';

function timeToMinutes(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

@Injectable()
export class OperatingHoursService {
  constructor(private readonly prisma: PrismaService) {}

  findAllForFacility(facilityId: number) {
    return this.prisma.operatingHours.findMany({
      where: { facilityId },
      orderBy: { dayOfWeek: 'asc' },
    });
  }

  async upsertOne(ownerId: number, facilityId: number, dto: UpsertOperatingHourDto) {
    await this.assertOwnership(ownerId, facilityId);
    this.assertValidRange(dto.openTime, dto.closeTime);

    return this.prisma.operatingHours.upsert({
      where: {
        facilityId_dayOfWeek: { facilityId, dayOfWeek: dto.dayOfWeek },
      },
      update: { openTime: dto.openTime, closeTime: dto.closeTime },
      create: { facilityId, ...dto },
    });
  }

  async upsertBulk(ownerId: number, facilityId: number, dto: BulkUpsertOperatingHoursDto) {
    await this.assertOwnership(ownerId, facilityId);
    dto.days.forEach((day) => this.assertValidRange(day.openTime, day.closeTime));

    return this.prisma.$transaction(
      dto.days.map((day) =>
        this.prisma.operatingHours.upsert({
          where: {
            facilityId_dayOfWeek: { facilityId, dayOfWeek: day.dayOfWeek },
          },
          update: { openTime: day.openTime, closeTime: day.closeTime },
          create: { facilityId, ...day },
        }),
      ),
    );
  }

  async remove(ownerId: number, facilityId: number, dayOfWeek: number) {
    await this.assertOwnership(ownerId, facilityId);

    const existing = await this.prisma.operatingHours.findUnique({
      where: { facilityId_dayOfWeek: { facilityId, dayOfWeek } },
    });
    if (!existing) {
      throw new NotFoundException(
        `Cơ sở ${facilityId} chưa có giờ hoạt động cho ngày ${dayOfWeek}`,
      );
    }

    await this.prisma.operatingHours.delete({
      where: { facilityId_dayOfWeek: { facilityId, dayOfWeek } },
    });
    return { deleted: true };
  }


  async isWithinOperatingHours(
    facilityId: number,
    dayOfWeek: number,
    startTime: string,
    endTime: string,
  ): Promise<boolean> {
    const hours = await this.prisma.operatingHours.findUnique({
      where: { facilityId_dayOfWeek: { facilityId, dayOfWeek } },
    });
    if (!hours) return false;

    return (
      timeToMinutes(startTime) >= timeToMinutes(hours.openTime) &&
      timeToMinutes(endTime) <= timeToMinutes(hours.closeTime)
    );
  }

  private assertValidRange(openTime: string, closeTime: string) {
    if (timeToMinutes(openTime) >= timeToMinutes(closeTime)) {
      throw new BadRequestException('openTime phải nhỏ hơn closeTime');
    }
  }

  private async assertOwnership(ownerId: number, facilityId: number) {
    const facility = await this.prisma.facility.findUnique({ where: { id: facilityId } });
    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }
    if (facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền cập nhật giờ hoạt động của cơ sở này');
    }
    return facility;
  }
}
