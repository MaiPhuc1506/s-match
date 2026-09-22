import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateFacilityDto } from './dto/create-facility.dto';
import { CreateCourtDto } from './dto/create-court.dto';

@Injectable()
export class FacilitiesService {
  constructor(private readonly prisma: PrismaService) {}

  // 1. Tạo cơ sở sân mới (Chỉ dành cho Court Owner)
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

  // 2. Lấy danh sách các cơ sở thuộc về chính Owner đang đăng nhập
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

  // 3. Xem chi tiết một cơ sở (kèm danh sách sân con)
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

  // 4. Thêm sân cầu lông con vào một cơ sở (Kiểm tra quyền sở hữu)
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
}