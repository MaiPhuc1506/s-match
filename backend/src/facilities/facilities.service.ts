import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFacilityDto } from './dto/create-facility.dto';
import { CreateCourtDto } from './dto/create-court.dto';
import { UpdateFacilityDto } from './dto/update-facility.dto';
import { UpdateCourtDto } from './dto/update-court.dto';
import { Role } from '../auth/roles.enum';

@Injectable()
export class FacilitiesService {
  constructor(private readonly prisma: PrismaService) {}

  async createFacility(ownerId: number, dto: CreateFacilityDto) {
    return this.prisma.facility.create({
      data: {
        ownerId,
        name: dto.name,
        address: dto.address,
        latitude: dto.latitude,
        longitude: dto.longitude,
        contactPhone: dto.contactPhone,
        description: dto.description,
      },
    });
  }

  async getMyFacilities(ownerId: number) {
    return this.prisma.facility.findMany({
      where: { ownerId },
      include: {
        courts: true,
        operatingHours: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPublicFacilities() {
    return this.prisma.facility.findMany({
      include: {
        courts: { include: { timeSlots: true } },
        operatingHours: true,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getFacilityById(id: number) {
    const facility = await this.prisma.facility.findUnique({
      where: { id },
      include: {
        courts: { include: { timeSlots: true } },
        operatingHours: true,
      },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${id}`);
    }

    return facility;
  }

  async addCourt(ownerId: number, facilityId: number, dto: CreateCourtDto, userRole?: string) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền thêm sân vào cơ sở này');
    }

    return this.prisma.court.create({
      data: {
        facilityId,
        name: dto.name,
        courtType: dto.courtType || 'INDOOR',
        status: dto.status || 'ACTIVE',
      },
    });
  }

  async updateFacility(ownerId: number, facilityId: number, dto: UpdateFacilityDto, userRole?: string) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền cập nhật cơ sở này');
    }

    return this.prisma.facility.update({
      where: { id: facilityId },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.address !== undefined && { address: dto.address }),
        ...(dto.latitude !== undefined && { latitude: dto.latitude }),
        ...(dto.longitude !== undefined && { longitude: dto.longitude }),
        ...(dto.contactPhone !== undefined && { contactPhone: dto.contactPhone }),
        ...(dto.description !== undefined && { description: dto.description }),
      },
      include: { courts: true },
    });
  }

  async deleteFacility(ownerId: number, facilityId: number, userRole?: string) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền xóa cơ sở này (cơ sở thuộc chủ sân khác)');
    }

    await this.prisma.$transaction(async (tx) => {
      // 1. Tìm tất cả các sân con của cơ sở
      const courts = await tx.court.findMany({
        where: { facilityId },
        select: { id: true },
      });
      const courtIds = courts.map((c) => c.id);

      if (courtIds.length > 0) {
        // 2. Tìm tất cả các booking thuộc các sân này
        const bookings = await tx.booking.findMany({
          where: { courtId: { in: courtIds } },
          select: { id: true },
        });
        const bookingIds = bookings.map((b) => b.id);

        if (bookingIds.length > 0) {
          // Gỡ liên kết Match -> Booking để không bị vi phạm khóa ngoại
          await tx.match.updateMany({
            where: { bookingId: { in: bookingIds } },
            data: { bookingId: null },
          });

          // Xóa các booking
          await tx.booking.deleteMany({
            where: { id: { in: bookingIds } },
          });
        }

        // 3. Xóa các TimeSlots của sân con
        await tx.timeSlot.deleteMany({
          where: { courtId: { in: courtIds } },
        });

        // 4. Xóa các sân con
        await tx.court.deleteMany({
          where: { id: { in: courtIds } },
        });
      }

      // 5. Xóa giờ hoạt động của cơ sở
      await tx.operatingHours.deleteMany({
        where: { facilityId },
      });

      // 6. Xóa chính cơ sở
      await tx.facility.delete({
        where: { id: facilityId },
      });
    });

    return { message: `Đã xóa cơ sở "${facility.name}" thành công` };
  }

  async updateCourt(ownerId: number, facilityId: number, courtId: number, dto: UpdateCourtDto, userRole?: string) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền cập nhật sân trong cơ sở này');
    }

    const court = await this.prisma.court.findUnique({
      where: { id: courtId },
    });

    if (!court || court.facilityId !== facilityId) {
      throw new NotFoundException(`Không tìm thấy sân với ID ${courtId} trong cơ sở này`);
    }

    return this.prisma.court.update({
      where: { id: courtId },
      data: {
        ...(dto.name !== undefined && { name: dto.name }),
        ...(dto.courtType !== undefined && { courtType: dto.courtType }),
        ...(dto.status !== undefined && { status: dto.status }),
      },
    });
  }

  async deleteCourt(ownerId: number, facilityId: number, courtId: number, userRole?: string) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền xóa sân trong cơ sở này');
    }

    const court = await this.prisma.court.findUnique({
      where: { id: courtId },
    });

    if (!court || court.facilityId !== facilityId) {
      throw new NotFoundException(`Không tìm thấy sân với ID ${courtId} trong cơ sở này`);
    }

    await this.prisma.$transaction(async (tx) => {
      // 1. Tìm các booking của sân này
      const bookings = await tx.booking.findMany({
        where: { courtId },
        select: { id: true },
      });
      const bookingIds = bookings.map((b) => b.id);

      if (bookingIds.length > 0) {
        // Gỡ liên kết Match -> Booking
        await tx.match.updateMany({
          where: { bookingId: { in: bookingIds } },
          data: { bookingId: null },
        });

        // Xóa bookings
        await tx.booking.deleteMany({
          where: { id: { in: bookingIds } },
        });
      }

      // 2. Xóa time slots của sân
      await tx.timeSlot.deleteMany({
        where: { courtId },
      });

      // 3. Xóa sân
      await tx.court.delete({
        where: { id: courtId },
      });
    });

    return { message: `Đã xóa sân "${court.name}" thành công` };
  }
}
