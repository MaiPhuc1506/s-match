import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAvailabilityDto, UpdateAvailabilityDto } from './dto/availability.dto';

const PRISMA_UNIQUE_CONSTRAINT_ERROR = 'P2002';

function timeToMinutes(time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  return hours * 60 + minutes;
}

@Injectable()
export class AvailabilityService {
  constructor(private readonly prisma: PrismaService) {}

  findAllForUser(userId: number) {
    return this.prisma.availability.findMany({
      where: { userId },
      orderBy: [{ dayOfWeek: 'asc' }, { startTime: 'asc' }],
    });
  }

  async create(userId: number, dto: CreateAvailabilityDto) {
    this.assertValidRange(dto.startTime, dto.endTime);
    await this.assertNoOverlap(userId, dto.dayOfWeek, dto.startTime, dto.endTime);

    try {
      return await this.prisma.availability.create({
        data: { userId, ...dto },
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === PRISMA_UNIQUE_CONSTRAINT_ERROR
      ) {
        throw new BadRequestException('Khung giờ này đã tồn tại');
      }
      throw err;
    }
  }

  async update(userId: number, id: number, dto: UpdateAvailabilityDto) {
    const existing = await this.assertOwnership(userId, id);

    const startTime = dto.startTime ?? existing.startTime;
    const endTime = dto.endTime ?? existing.endTime;
    const dayOfWeek = dto.dayOfWeek ?? existing.dayOfWeek;
    this.assertValidRange(startTime, endTime);
    await this.assertNoOverlap(userId, dayOfWeek, startTime, endTime, id);

    return this.prisma.availability.update({
      where: { id },
      data: { dayOfWeek, startTime, endTime },
    });
  }

  async remove(userId: number, id: number) {
    await this.assertOwnership(userId, id);
    await this.prisma.availability.delete({ where: { id } });
    return { deleted: true };
  }

  private assertValidRange(startTime: string, endTime: string) {
    if (timeToMinutes(startTime) >= timeToMinutes(endTime)) {
      throw new BadRequestException('startTime phải nhỏ hơn endTime');
    }
  }

  private async assertOwnership(userId: number, id: number) {
    const slot = await this.prisma.availability.findUnique({ where: { id } });
    if (!slot) {
      throw new NotFoundException(`Không tìm thấy khung giờ ${id}`);
    }
    if (slot.userId !== userId) {
      throw new ForbiddenException('Bạn không có quyền chỉnh sửa khung giờ này');
    }
    return slot;
  }

  /** Rejects overlapping ranges on the same day (e.g. 18:00-21:00 vs 19:00-20:00). */
  private async assertNoOverlap(
    userId: number,
    dayOfWeek: number,
    startTime: string,
    endTime: string,
    excludeId?: number,
  ) {
    const sameDaySlots = await this.prisma.availability.findMany({
      where: { userId, dayOfWeek, ...(excludeId ? { id: { not: excludeId } } : {}) },
    });

    const newStart = timeToMinutes(startTime);
    const newEnd = timeToMinutes(endTime);

    const overlaps = sameDaySlots.some((slot) => {
      const existingStart = timeToMinutes(slot.startTime);
      const existingEnd = timeToMinutes(slot.endTime);
      return newStart < existingEnd && existingStart < newEnd;
    });

    if (overlaps) {
      throw new BadRequestException('Khung giờ này bị trùng với một khung giờ đã có');
    }
  }

  /**
   * Expands this user's recurring weekly availability into concrete ISO
   * datetime strings for the next `daysAhead` days — exactly the
   * `available_time_slots: List[str]` shape the Matchmaking Service's
   * PlayerProfile schema expects (see matchmaking/app/schemas.py).
   *
   * Intended for SMM-11 (Matchmaking Input Model) to call when building the
   * payload sent to the Python service, so that logic isn't duplicated there.
   */
  async getUpcomingTimeSlots(userId: number, daysAhead = 7): Promise<string[]> {
    const slots = await this.findAllForUser(userId);
    if (slots.length === 0) {
      return [];
    }

    const result: string[] = [];
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    for (let offset = 0; offset < daysAhead; offset += 1) {
      const date = new Date(today);
      date.setDate(date.getDate() + offset);
      const dayOfWeek = date.getDay();

      for (const slot of slots) {
        if (slot.dayOfWeek !== dayOfWeek) continue;
        const [hours, minutes] = slot.startTime.split(':').map(Number);
        const slotDate = new Date(date);
        slotDate.setHours(hours, minutes, 0, 0);
        result.push(slotDate.toISOString());
      }
    }

    return result;
  }
}
