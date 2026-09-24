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

  async getFacilityById(id: number) {
    const facility = await this.prisma.facility.findUnique({
      where: { id },
      include: {
        courts: true,
        operatingHours: true,
      },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${id}`);
    }

    return facility;
  }

  async addCourt(ownerId: number, facilityId: number, dto: CreateCourtDto) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (facility.ownerId !== ownerId) {
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

  async updateFacility(ownerId: number, facilityId: number, dto: UpdateFacilityDto) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (facility.ownerId !== ownerId) {
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

  async deleteFacility(ownerId: number, facilityId: number) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền xóa cơ sở này');
    }

    await this.prisma.facility.delete({
      where: { id: facilityId },
    });

    return { message: `Đã xóa cơ sở "${facility.name}" thành công` };
  }

  async updateCourt(ownerId: number, facilityId: number, courtId: number, dto: UpdateCourtDto) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (facility.ownerId !== ownerId) {
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

  async deleteCourt(ownerId: number, facilityId: number, courtId: number) {
    const facility = await this.prisma.facility.findUnique({
      where: { id: facilityId },
    });

    if (!facility) {
      throw new NotFoundException(`Không tìm thấy cơ sở với ID ${facilityId}`);
    }

    if (facility.ownerId !== ownerId) {
      throw new ForbiddenException('Bạn không có quyền xóa sân trong cơ sở này');
    }

    const court = await this.prisma.court.findUnique({
      where: { id: courtId },
    });

    if (!court || court.facilityId !== facilityId) {
      throw new NotFoundException(`Không tìm thấy sân với ID ${courtId} trong cơ sở này`);
    }

    await this.prisma.court.delete({
      where: { id: courtId },
    });

    return { message: `Đã xóa sân "${court.name}" thành công` };
  }
}