import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpsertPreferenceDto } from './dto/preference.dto';

@Injectable()
export class PreferenceService {
  constructor(private readonly prisma: PrismaService) {}

  findForUser(userId: number) {
    return this.prisma.playingPreference.findUnique({ where: { userId } });
  }

  upsert(userId: number, dto: UpsertPreferenceDto) {
    if (dto.minSkillLevel > dto.maxSkillLevel) {
      throw new BadRequestException(
        'minSkillLevel không được lớn hơn maxSkillLevel',
      );
    }

    return this.prisma.playingPreference.upsert({
      where: { userId },
      update: { ...dto },
      create: { userId, ...dto },
    });
  }
}
