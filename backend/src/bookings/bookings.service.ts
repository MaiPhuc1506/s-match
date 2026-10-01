import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { OperatingHoursService } from '../facilities/operating-hours.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { BookingStatus } from '@prisma/client';

export const DEFAULT_HOURLY_PRICE = 80000;

export function calculateBookingPrice(start: Date, end: Date, hourlyPrice = DEFAULT_HOURLY_PRICE): number {
  const durationMs = end.getTime() - start.getTime();
  const durationHours = durationMs / (1000 * 60 * 60);
  return Math.round(durationHours * hourlyPrice);
}

function extractTimeAndDay(isoString: string, date: Date): { dayOfWeek: number; timeStr: string } {
  const tIndex = isoString.indexOf('T');
  if (tIndex !== -1) {
    const timePart = isoString.substring(tIndex + 1, tIndex + 6);
    return { dayOfWeek: date.getUTCDay(), timeStr: timePart };
  }
  const hours = date.getUTCHours().toString().padStart(2, '0');
  const minutes = date.getUTCMinutes().toString().padStart(2, '0');
  return { dayOfWeek: date.getUTCDay(), timeStr: `${hours}:${minutes}` };
}

@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly operatingHoursService: OperatingHoursService,
  ) {}

  async create(userId: number, dto: CreateBookingDto) {
    const start = new Date(dto.startTime);
    const end = new Date(dto.endTime);

    // 1. Kiểm tra thời gian logic & không cho phép đặt ngày quá khứ
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Thời gian bắt đầu hoặc kết thúc không hợp lệ');
    }
    if (start >= end) {
      throw new BadRequestException('Thời gian kết thúc phải diễn ra sau thời gian bắt đầu');
    }

    const now = new Date();
    if (start <= now) {
      throw new BadRequestException('Không thể đặt sân cho thời gian trong quá khứ');
    }

    const durationMinutes = (end.getTime() - start.getTime()) / (1000 * 60);
    if (durationMinutes < 30) {
      throw new BadRequestException('Thời gian đặt sân tối thiểu là 30 phút');
    }

    // Đơn đặt sân phải nằm trong cùng 1 ngày
    if (start.toISOString().slice(0, 10) !== end.toISOString().slice(0, 10)) {
      throw new BadRequestException('Đơn đặt sân phải diễn ra trong cùng một ngày');
    }

    // 2. Sử dụng Prisma Transaction có Row Lock (pessimistic lock) để đảm bảo an toàn đồng thời
    return this.prisma.$transaction(async (tx) => {
      // Khóa bản ghi Court để tuần tự hóa các request đặt cùng sân này
      await tx.$executeRaw`SELECT id FROM "Court" WHERE id = ${dto.courtId} FOR UPDATE`;

      // Kiểm tra sân có tồn tại và đang hoạt động không
      const court = await tx.court.findUnique({
        where: { id: dto.courtId },
        include: { facility: true },
      });
      if (!court) {
        throw new NotFoundException(`Không tìm thấy sân với ID ${dto.courtId}`);
      }
      if (court.status !== 'ACTIVE') {
        throw new BadRequestException('Sân hiện đang bảo trì hoặc ngừng hoạt động');
      }

      // 3. Kiểm tra giờ hoạt động của cơ sở
      const startInfo = extractTimeAndDay(dto.startTime, start);
      const endInfo = extractTimeAndDay(dto.endTime, end);

      const isWithinHours = await this.operatingHoursService.isWithinOperatingHours(
        court.facilityId,
        startInfo.dayOfWeek,
        startInfo.timeStr,
        endInfo.timeStr,
      );

      if (!isWithinHours) {
        throw new BadRequestException('Khung giờ đặt sân nằm ngoài giờ hoạt động của cơ sở');
      }

      // 4. Chống Double-booking: Kiểm tra xung đột khung giờ
      const conflictingBooking = await tx.booking.findFirst({
        where: {
          courtId: dto.courtId,
          status: { in: [BookingStatus.CONFIRMED, BookingStatus.PENDING] },
          startTime: { lt: end },
          endTime: { gt: start },
        },
      });

      if (conflictingBooking) {
        throw new ConflictException(
          'Khung giờ này đã có người đặt trước. Vui lòng chọn khung giờ hoặc sân khác!',
        );
      }

      // 5. Giá được tính toán an toàn phía server
      const totalPrice = calculateBookingPrice(start, end);

      // 6. Tạo Booking
      return tx.booking.create({
        data: {
          userId,
          courtId: dto.courtId,
          startTime: start,
          endTime: end,
          totalPrice,
          note: dto.note,
          status: BookingStatus.CONFIRMED,
        },
        include: {
          court: {
            include: {
              facility: true,
            },
          },
        },
      });
    });
  }

  async findMyBookings(userId: number) {
    return this.prisma.booking.findMany({
      where: { userId },
      orderBy: { startTime: 'desc' },
      include: {
        court: {
          include: {
            facility: true,
          },
        },
      },
    });
  }

  async findOne(id: number, currentUserId: number, currentUserRole: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        user: {
          select: { id: true, email: true, fullName: true, phone: true },
        },
        court: {
          include: {
            facility: true,
          },
        },
      },
    });

    if (!booking) {
      throw new NotFoundException(`Không tìm thấy đơn đặt sân ID ${id}`);
    }

    const isOwner = booking.court.facility.ownerId === currentUserId;
    const isBooker = booking.userId === currentUserId;
    const isAdmin = currentUserRole === 'ADMIN';

    if (!isBooker && !isOwner && !isAdmin) {
      throw new ForbiddenException('Bạn không có quyền xem đơn đặt sân này');
    }

    return booking;
  }

  async cancel(id: number, currentUserId: number, currentUserRole: string) {
    const booking = await this.prisma.booking.findUnique({
      where: { id },
      include: {
        court: {
          include: {
            facility: true,
          },
        },
      },
    });

    if (!booking) {
      throw new NotFoundException(`Không tìm thấy đơn đặt sân ID ${id}`);
    }

    const isOwner = booking.court.facility.ownerId === currentUserId;
    const isBooker = booking.userId === currentUserId;
    const isAdmin = currentUserRole === 'ADMIN';

    if (!isBooker && !isOwner && !isAdmin) {
      throw new ForbiddenException('Bạn không có quyền hủy đơn đặt sân này');
    }

    if (booking.status === BookingStatus.CANCELLED) {
      throw new BadRequestException('Đơn đặt sân này đã được hủy trước đó');
    }

    if (booking.status === BookingStatus.COMPLETED) {
      throw new BadRequestException('Không thể hủy đơn đặt sân đã hoàn tất');
    }

    return this.prisma.booking.update({
      where: { id },
      data: { status: BookingStatus.CANCELLED },
      include: {
        court: true,
      },
    });
  }
}