import {
  ForbiddenException,
  ConflictException,
  BadRequestException,
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
    if ((dto.latitude == null) !== (dto.longitude == null)) {
      throw new BadRequestException('Latitude and longitude must be provided together.');
    }
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
        services: { orderBy: { sortOrder: 'asc' } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getPublicFacilities() {
    return this.prisma.facility.findMany({
      include: {
        courts: { include: { timeSlots: true } },
        operatingHours: true,
        services: { orderBy: { sortOrder: 'asc' } },
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
        services: { orderBy: { sortOrder: 'asc' } },
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

    const latitude = dto.latitude ?? facility.latitude;
    const longitude = dto.longitude ?? facility.longitude;
    if ((latitude == null) !== (longitude == null)) {
      throw new BadRequestException('Latitude and longitude must be provided together.');
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
    return this.prisma.$transaction(async (tx) => {
      // Lock the parent and child rows before checking history. Booking inserts
      // must acquire a foreign-key lock on the court and cannot race this check.
      const facilities = await tx.$queryRaw<{ id: number; ownerId: number; name: string }[]>`
        SELECT "id", "ownerId", "name" FROM "Facility" WHERE "id" = ${facilityId} FOR UPDATE
      `;
      const facility = facilities[0];
      if (!facility) throw new NotFoundException(`Facility ${facilityId} not found`);
      if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
        throw new ForbiddenException('You cannot delete another owner’s facility');
      }
      const courts = await tx.$queryRaw<{ id: number }[]>`
        SELECT "id" FROM "Court" WHERE "facilityId" = ${facilityId} ORDER BY "id" FOR UPDATE
      `;
      const courtIds = courts.map((court) => court.id);
      if (courtIds.length && await tx.booking.count({ where: { courtId: { in: courtIds } } })) {
        throw new ConflictException('This facility has booking history and cannot be deleted.');
      }
      await tx.timeSlot.deleteMany({ where: { courtId: { in: courtIds } } });
      await tx.court.deleteMany({ where: { facilityId } });
      await tx.operatingHours.deleteMany({ where: { facilityId } });
      await tx.facility.delete({ where: { id: facilityId } });
      return { message: `Facility "${facility.name}" deleted` };
    });
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
    return this.prisma.$transaction(async (tx) => {
      const facilities = await tx.$queryRaw<{ id: number; ownerId: number }[]>`
        SELECT "id", "ownerId" FROM "Facility" WHERE "id" = ${facilityId} FOR UPDATE
      `;
      const facility = facilities[0];
      if (!facility) throw new NotFoundException(`Facility ${facilityId} not found`);
      if (userRole !== Role.ADMIN && facility.ownerId !== ownerId) {
        throw new ForbiddenException('You cannot delete another owner’s court');
      }
      const courts = await tx.$queryRaw<{ id: number; name: string }[]>`
        SELECT "id", "name" FROM "Court" WHERE "id" = ${courtId} AND "facilityId" = ${facilityId} FOR UPDATE
      `;
      const court = courts[0];
      if (!court) throw new NotFoundException(`Court ${courtId} not found in this facility`);
      if (await tx.booking.count({ where: { courtId } })) {
        throw new ConflictException('This court has booking history and cannot be deleted.');
      }
      await tx.timeSlot.deleteMany({ where: { courtId } });
      await tx.court.delete({ where: { id: courtId } });
      return { message: `Court "${court.name}" deleted` };
    });
  }
}
