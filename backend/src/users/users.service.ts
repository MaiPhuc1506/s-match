import { Injectable } from '@nestjs/common';
import { RoleName } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

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
