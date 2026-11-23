import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { vietnamDay } from '../bookings/booking-time';
import { BookingStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OperatingHoursService } from './operating-hours.service';
import { CreateTimeSlotDto, UpdateTimeSlotDto } from './dto/time-slot.dto';
import { Role } from '../auth/roles.enum';

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

  // Prices are weekly templates; occupancy is resolved for Vietnam's calendar day.
  async getAvailabilityForDate(facilityId: number, courtId: number, date: string) {
    const day = vietnamDay(date);
    const court = await this.assertCourtBelongsToFacility(facilityId, courtId);
    if (court.status !== 'ACTIVE') return [];
    const [slots, bookings, hours] = await Promise.all([
      this.prisma.timeSlot.findMany({
        where: { courtId, dayOfWeek: day.dayOfWeek },
        orderBy: { startTime: 'asc' },
      }),
      this.prisma.booking.findMany({
        where: { courtId, status: { in: [BookingStatus.PENDING, BookingStatus.CONFIRMED] },
          startTime: { lt: day.end }, endTime: { gt: day.start } },
        select: { startTime: true, endTime: true, status: true, match: { select: { id: true, privacy: true, status: true, maxPlayers: true, _count: { select: { participants: { where: { status: 'ACCEPTED' } } } } } } },
      }),
      this.operatingHoursService.findAllForFacility(facilityId),
    ]);
    const result: Array<{
      id: number | null; courtId: number; dayOfWeek: number;
      startTime: string; endTime: string; price: number | null;
      isActive: boolean; isBooked: boolean; status: string; openMatchId?: number; openMatchPlayers?: number; openMatchCapacity?: number;
    }> = [];
    for (const slot of slots) {
      const start = new Date(`${date}T${slot.startTime}:00+07:00`);
      const end = new Date(`${date}T${slot.endTime}:00+07:00`);
      const isBooked = bookings.some((b) => b.startTime < end && b.endTime > start);
      const withinHours = await this.operatingHoursService.isWithinOperatingHours(facilityId, day.dayOfWeek, slot.startTime, slot.endTime);
      // Do not show inactive templates superseded by an active overlapping
      // template. Other inactive templates within opening hours are real locks.
      const representedByActiveSlot = !slot.isActive && slots.some((other) =>
        other.isActive && other.startTime < slot.endTime && other.endTime > slot.startTime &&
        (!isBooked || bookings.some((booking) =>
          booking.startTime < end && booking.endTime > start &&
          booking.startTime < new Date(`${date}T${other.endTime}:00+07:00`) &&
          booking.endTime > new Date(`${date}T${other.startTime}:00+07:00`),
        )),
      );
      if (!representedByActiveSlot && (withinHours || isBooked)) {
        const isActive = slot.isActive && withinHours;
        result.push({ ...slot, isActive, isBooked, status: isBooked ? 'BOOKED' : isActive ? 'AVAILABLE' : 'LOCKED' });
      }
    }
    // The closing cell is supplied by the API rather than invented by clients.
    const dayHours = hours.find((h) => h.dayOfWeek === day.dayOfWeek);
    if (dayHours && timeToMinutes(dayHours.closeTime) <= 23 * 60 &&
        !result.some((s) => s.startTime === '23:00' && s.endTime === '24:00')) {
      result.push({
        id: null, courtId, dayOfWeek: day.dayOfWeek, startTime: '23:00',
        endTime: '24:00', price: null, isActive: false, isBooked: false, status: 'LOCKED',
      });
    }
    // Expose half-hour discovery cells while keeping weekly tariff templates intact.
    const cells = result.flatMap((slot) => {
      const cells: typeof result = [];
      const startMinute = timeToMinutes(slot.startTime);
      const endMinute = timeToMinutes(slot.endTime);
      for (let minute = startMinute; minute < endMinute; minute += 30) {
        const finish = Math.min(minute + 30, endMinute);
        const clock = (value: number) => `${String(Math.floor(value / 60)).padStart(2, '0')}:${String(value % 60).padStart(2, '0')}`;
        const startTime = clock(minute), endTime = clock(finish);
        const start = new Date(`${date}T${startTime}:00+07:00`);
        const end = new Date(`${date}T${endTime}:00+07:00`);
        const overlaps = bookings.filter((b) => b.startTime < end && b.endTime > start);
        const isBooked = overlaps.length > 0;
        // Public Open Match metadata is additive: the slot remains BOOKED.
        const openMatch = overlaps.find((b) => b.status === BookingStatus.CONFIRMED && b.match?.privacy === 'OPEN' && (b.match.status === 'OPEN' || b.match.status === 'FULL'))?.match;
        cells.push({ ...slot, startTime, endTime,
          ...(openMatch ? { openMatchId: openMatch.id, openMatchPlayers: openMatch._count?.participants, openMatchCapacity: openMatch.maxPlayers } : {}),
          price: slot.price == null ? null : slot.price * (finish - minute) / (endMinute - startMinute),
          isBooked, status: isBooked ? 'BOOKED' : slot.isActive ? 'AVAILABLE' : 'LOCKED' });
      }
      return cells;
    });
    return cells.filter((cell) => !cells.some((other) =>
      other !== cell && other.isActive && !cell.isActive &&
      other.startTime === cell.startTime && other.endTime === cell.endTime));
  }

  async create(ownerId: number, facilityId: number, courtId: number, dto: CreateTimeSlotDto, userRole?: string) {
    await this.assertOwnership(ownerId, facilityId, courtId, userRole);
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
    userRole?: string,
  ) {
    const slot = await this.assertSlotOwnership(ownerId, facilityId, courtId, slotId, userRole);

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
        ...((dto.startTime !== undefined || dto.endTime !== undefined)
          ? { hourlyRate: null, walkInPrice: null }
          : dto.price !== undefined && slot.hourlyRate != null
            ? { hourlyRate: dto.price * 60 / (timeToMinutes(endTime) - timeToMinutes(startTime)) }
            : {}),
        ...(dto.isActive !== undefined && { isActive: dto.isActive }),
      },
    });
  }

  async remove(ownerId: number, facilityId: number, courtId: number, slotId: number, userRole?: string) {
    await this.assertSlotOwnership(ownerId, facilityId, courtId, slotId, userRole);
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

  private async assertOwnership(ownerId: number, facilityId: number, courtId: number, userRole?: string) {
    const facility = await this.prisma.facility.findUnique({ where: { id: facilityId } });
    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }
    if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
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
    userRole?: string,
  ) {
    await this.assertOwnership(ownerId, facilityId, courtId, userRole);
    const slot = await this.prisma.timeSlot.findUnique({ where: { id: slotId } });
    if (!slot || slot.courtId !== courtId) {
      throw new NotFoundException(`Không tìm thấy khung giờ với ID ${slotId} trong sân này`);
    }
    return slot;
  }
}
