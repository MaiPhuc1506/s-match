import { Injectable } from '@nestjs/common';
import { Prisma, RoleName } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

const API_USER_SELECT = {
  id: true,
  fullName: true,
  role: { select: { name: true } },
} satisfies Prisma.UserSelect;

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  findAllForApi() {
    return this.prisma.user.findMany({
      select: API_USER_SELECT,
      orderBy: { createdAt: 'desc' },
    });
  }

  findByIdForApi(id: number) {
    return this.prisma.user.findUnique({
      where: { id },
      select: API_USER_SELECT,
    });
  }

  findByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: { email },
      include: { role: true },
    });
  }

  findById(id: number) {
    return this.prisma.user.findUnique({
      where: { id },
      include: { role: true },
    });
  }

  findAll() {
    return this.prisma.user.findMany({
      include: { role: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createUser(params: {
    email: string;
    passwordHash: string;
    fullName: string;
    phone?: string;
    role: RoleName;
  }) {
    const role = await this.prisma.role.upsert({
      where: { name: params.role },
      update: {},
      create: { name: params.role },
    });

    return this.prisma.user.create({
      data: {
        email: params.email,
        password: params.passwordHash,
        fullName: params.fullName,
        phone: params.phone,
        roleId: role.id,
      },
      include: { role: true },
    });
  }
}
