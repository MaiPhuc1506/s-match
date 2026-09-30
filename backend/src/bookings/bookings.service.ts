import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { BookingStatus } from '@prisma/client';

@Injectable()
export class BookingsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(userId: number, dto: CreateBookingDto) {
    const start = new Date(dto.startTime);
    const end = new Date(dto.endTime);

    // 1. Kiểm tra thời gian logic
    if (isNaN(start.getTime()) || isNaN(end.getTime())) {
      throw new BadRequestException('Thời gian bắt đầu hoặc kết thúc không hợp lệ');
    }
    if (start >= end) {
      throw new BadRequestException('Thời gian kết thúc phải diễn ra sau thời gian bắt đầu');
    }

    // 2. Kiểm tra sân có tồn tại và đang hoạt động không
    const court = await this.prisma.court.findUnique({
      where: { id: dto.courtId },
      include: { facility: true },
    });
    if (!court) {
      throw new NotFoundException(`Không tìm thấy sân với ID ${dto.courtId}`);
    }
    if (court.status !== 'ACTIVE') {
      throw new BadRequestException('Sân hiện đang bảo trì hoặc ngừng hoạt động');
    }

    // 3. Chống Double-booking: Kiểm tra xung đột khung giờ
    // Hai khoảng [A, B] và [C, D] trùng nhau khi và chỉ khi: A < D && B > C
    const conflictingBooking = await this.prisma.booking.findFirst({
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

    // 4. Tạo Booking
    return this.prisma.booking.create({
      data: {
        userId,
        courtId: dto.courtId,
        startTime: start,
        endTime: end,
        totalPrice: dto.totalPrice ?? 0,
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

    // Chỉ người đặt, chủ sở hữu sân, hoặc ADMIN mới được xem chi tiết
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

    return this.prisma.booking.update({
      where: { id },
      data: { status: BookingStatus.CANCELLED },
      include: {
        court: true,
      },
    });
  }
}