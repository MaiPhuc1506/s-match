import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class PlayersService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyProfile(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        fullName: true,
        phone: true,
        role: { select: { name: true } },
        playerProfile: true,
      },
    });

    if (!user) {
      throw new NotFoundException('Không tìm thấy thông tin người dùng');
    }

    if (!user.playerProfile) {
      const newProfile = await this.prisma.playerProfile.create({
        data: { userId },
      });
      return { ...user, playerProfile: newProfile };
    }

    return user;
  }

  async updateMyProfile(userId: number, dto: UpdateProfileDto) {
    const { fullName, phone, ...profileData } = dto;

    const updatedUser = await this.prisma.user.update({
      where: { id: userId },
      data: {
        fullName,
        phone,
        playerProfile: {
          upsert: {
            create: profileData,
            update: profileData,
          },
        },
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phone: true,
        playerProfile: true,
      },
    });

    return updatedUser;
  }
}