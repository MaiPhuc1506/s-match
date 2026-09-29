import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OperatingHoursService } from './operating-hours.service';
import { CreateTimeSlotDto, UpdateTimeSlotDto } from './dto/time-slot.dto';

const PRISMA_UNIQUE_CONSTRAINT_ERROR = 'P2002';

function timeToMinutes(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

@Injectable()
export class TimeSlotsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly operatingHoursService: OperatingHoursService,
  ) {}

  // Public — Player xem các khung giờ + giá của một sân
  findAllForCourt(facilityId: number, courtId: number) {
    return this.assertCourtBelongsToFacility(facilityId, courtId).then(() =>
      this.prisma.timeSlot.findMany({
        where: { courtId },
        orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
      }),
    );
  }

  /**
   * Trả về các khung giờ (kèm giá) của sân cho một ngày cụ thể, dựa trên
   * dayOfWeek suy ra từ `date`. CHƯA đối chiếu với bảng Booking (SMM-18 chưa
   * tồn tại tại thời điểm ticket này được làm) — SMM-18 nên mở rộng hàm này
   * (hoặc gọi thêm) để đánh dấu `isBooked` cho từng slot khi Booking model
   * đã có.
   */
  async getAvailabilityForDate(facilityId: number, courtId: number, date: string) {
    await this.assertCourtBelongsToFacility(facilityId, courtId);

    const dayOfWeek = new Date(date).getUTCDay();
    return this.prisma.timeSlot.findMany({
      where: { courtId, dayOfWeek, isActive: true },
      orderBy: { startTime: 'asc' },
    });
  }

  async create(ownerId: number, facilityId: number, courtId: number, dto: CreateTimeSlotDto) {
    await this.assertOwnership(ownerId, facilityId, courtId);
    this.assertValidRange(dto.startTime, dto.endTime);

    const withinOperatingHours = await this.operatingHoursService.isWithinOperatingHours(
      facilityId,
      dto.dayOfWeek,
      dto.startTime,
      dto.endTime,
    );
    if (!withinOperatingHours) {
      throw new BadRequestException(
        'Khung giờ này nằm ngoài giờ hoạt động của cơ sở. Vui lòng cập nhật giờ hoạt động trước.',
      );
    }

    await this.assertNoOverlap(courtId, dto.dayOfWeek, dto.startTime, dto.endTime);

    try {
      return await this.prisma.timeSlot.create({
        data: { courtId, ...dto },
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === PRISMA_UNIQUE_CONSTRAINT_ERROR
      ) {
        throw new BadRequestException('Khung giờ này đã tồn tại cho sân này');
      }
      throw err;
    }
  }

  async update(
    ownerId: number,
    facilityId: number,
    courtId: number,
    slotId: number,
    dto: UpdateTimeSlotDto,
  ) {
    const slot = await this.assertSlotOwnership(ownerId, facilityId, courtId, slotId);

    const startTime = dto.startTime ?? slot.startTime;
    const endTime = dto.endTime ?? slot.endTime;
    this.assertValidRange(startTime, endTime);

    if (dto.startTime || dto.endTime) {
      const withinOperatingHours = await this.operatingHoursService.isWithinOperatingHours(
        facilityId,
        slot.dayOfWeek,
        startTime,
        endTime,
      );
      if (!withinOperatingHours) {
        throw new BadRequestException('Khung giờ này nằm ngoài giờ hoạt động của cơ sở.');
      }
      await this.assertNoOverlap(courtId, slot.dayOfWeek, startTime, endTime, slotId);
    }

    return this.prisma.timeSlot.update({
      where: { id: slotId },
      data: {
        ...(dto.startTime !== undefined && { startTime: dto.startTime }),
        ...(dto.endTime !== undefined && { endTime: dto.endTime }),
        ...(dto.price !== undefined && { price: dto.price }),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });
  }

  async remove(ownerId: number, facilityId: number, courtId: number, slotId: number) {
    await this.assertSlotOwnership(ownerId, facilityId, courtId, slotId);
    await this.prisma.timeSlot.delete({ where: { id: slotId } });
    return { deleted: true };
  }

  private assertValidRange(startTime: string, endTime: string) {
    if (timeToMinutes(startTime) >= timeToMinutes(endTime)) {
      throw new BadRequestException('startTime phải nhỏ hơn endTime');
    }
  }

  private async assertNoOverlap(
    courtId: number,
    dayOfWeek: number,
    startTime: string,
    endTime: string,
    excludeId?: number,
  ) {
    const sameDaySlots = await this.prisma.timeSlot.findMany({
      where: { courtId, dayOfWeek, ...(excludeId ? { id: { not: excludeId } } : {}) },
    });

    const newStart = timeToMinutes(startTime);
    const newEnd = timeToMinutes(endTime);

    const overlaps = sameDaySlots.some((slot) => {
      const existingStart = timeToMinutes(slot.startTime);
      const existingEnd = timeToMinutes(slot.endTime);
      return newStart < existingEnd && existingStart < newEnd;
    });

    if (overlaps) {
      throw new BadRequestException('Khung giờ này bị trùng với một khung giờ đã có của sân');
    }
  }

  private async assertCourtBelongsToFacility(facilityId: number, courtId: number) {
    const court = await this.prisma.court.findUnique({ where: { id: courtId } });
    if (!court || court.facilityId !== facilityId) {
      throw new NotFoundException(`Không tìm thấy sân với ID ${courtId} trong cơ sở này`);
    }
    return court;
  }

  private async assertOwnership(ownerId: number, facilityId: number, courtId: number) {
    const facility = await this.prisma.facility.findUnique({ where: { id: facilityId } });
    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }
    if (facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền can thiệp vào cơ sở này');
    }
    await this.assertCourtBelongsToFacility(facilityId, courtId);
    return facility;
  }

  private async assertSlotOwnership(
    ownerId: number,
    facilityId: number,
    courtId: number,
    slotId: number,
  ) {
    await this.assertOwnership(ownerId, facilityId, courtId);
    const slot = await this.prisma.timeSlot.findUnique({ where: { id: slotId } });
    if (!slot || slot.courtId !== courtId) {
      throw new NotFoundException(`Không tìm thấy khung giờ với ID ${slotId} trong sân này`);
    }
    return slot;
  }
}
