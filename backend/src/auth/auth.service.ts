import { PrismaService } from '../prisma/prisma.service';
import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'node:crypto';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { Prisma, RoleName } from '@prisma/client';
import { AuthTokensService } from './auth-tokens.service';

@Injectable()
export class AuthService {
  constructor(
  private readonly prisma: PrismaService,
  private readonly tokens: AuthTokensService,
) {}

  async register(registerDto: RegisterDto) {
    const email = registerDto.email.trim().toLowerCase();
    const existingUser = await this.prisma.user.findFirst({
      where: { email: { equals: email, mode: 'insensitive' } },
      select: { id: true },
    });
    if (existingUser) {
      throw new BadRequestException('Email đã được sử dụng');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);

    try {
      const newUser = await this.prisma.user.create({
        data: {
          email,
          password: hashedPassword,
          fullName: registerDto.fullName,
          phone: registerDto.phoneNumber,
          role: {
            connectOrCreate: {
              where: { name: RoleName.PLAYER },
              create: { name: RoleName.PLAYER },
            },
          },
        },
        select: { id: true, email: true, fullName: true },
      });

      return {
        message: 'Đăng ký thành công',
        data: {
          id: newUser.id,
          email: newUser.email,
          fullName: newUser.fullName,
          // Preserve the existing Register response; the stored role is PLAYER.
          role: 'Player',
        },
      };
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002' &&
        (Array.isArray(error.meta?.target)
          ? error.meta.target.includes('email')
          : typeof error.meta?.target === 'string' && error.meta.target.includes('email'))
      ) {
        throw new BadRequestException('Email đã được sử dụng');
      }
      throw error;
    }
  }

  async login(loginDto: LoginDto) {
  const user = await this.prisma.user.findFirst({
    where: { email: { equals: loginDto.email.trim().toLowerCase(), mode: 'insensitive' } },
    include: { role: true },
  });

  if (!user) {
    throw new UnauthorizedException('Sai email hoặc mật khẩu');
  }

  const isPasswordValid = await bcrypt.compare(loginDto.password, user.password);
  if (!isPasswordValid) {
    throw new UnauthorizedException('Sai email hoặc mật khẩu');
  }

  const roleName = user.role?.name;
  if (!roleName || !Object.values(RoleName).includes(roleName)) {
    throw new UnauthorizedException('Tài khoản không có quyền hợp lệ');
  }
  const sessionId = randomUUID();
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
  const { accessToken, refreshToken } = await this.tokens.issuePair(
    { id: user.id, email: user.email, role: roleName }, sessionId, expiresAt,
  );
  await this.prisma.refreshSession.create({
    data: {
      id: sessionId,
      userId: user.id,
      refreshTokenHash: this.tokens.hashRefreshToken(refreshToken),
      expiresAt,
    },
  });

  return {
    message: 'Đăng nhập thành công',
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      email: user.email,
      fullName: user.fullName,
      role: roleName,
    },
  };
}

  async refreshTokens(refreshToken: string) {
    const payload = await this.tokens.verify(refreshToken, 'refresh');
    const session = await this.prisma.refreshSession.findUnique({
      where: { id: payload.sid },
      include: { user: { select: { id: true, email: true, role: { select: { name: true } } } } },
    });
    if (!session || session.userId !== payload.sub || session.revokedAt || session.expiresAt <= new Date()) {
      throw new UnauthorizedException('Refresh token không hợp lệ hoặc đã hết hạn');
    }
    if (!this.tokens.matchesRefreshHash(refreshToken, session.refreshTokenHash)) {
      await this.revokeSession(payload.sub, payload.sid);
      throw new UnauthorizedException('Refresh token không hợp lệ hoặc đã hết hạn');
    }
    const user = session.user;
    const role = user?.role?.name;
    if (!user || !role || !Object.values(RoleName).includes(role)) {
      await this.revokeSession(payload.sub, payload.sid);
      throw new UnauthorizedException('Tài khoản không có quyền hợp lệ');
    }
    const pair = await this.tokens.issuePair(
      { id: user.id, email: user.email, role }, session.id, session.expiresAt,
    );
    // Compare-and-swap: PostgreSQL rechecks the predicate after a competing update.
    const rotated = await this.prisma.refreshSession.updateMany({
      where: {
        id: session.id,
        userId: payload.sub,
        refreshTokenHash: session.refreshTokenHash,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      data: { refreshTokenHash: this.tokens.hashRefreshToken(pair.refreshToken), lastUsedAt: new Date() },
    });
    if (rotated.count !== 1) {
      // Commit revocation before returning 401; do not roll it back by throwing in a transaction.
      await this.revokeSession(payload.sub, payload.sid);
      throw new UnauthorizedException('Refresh token không hợp lệ hoặc đã hết hạn');
    }
    return pair;
  }

  private revokeSession(userId: number, sessionId: string) {
    return this.prisma.refreshSession.updateMany({
      where: { id: sessionId, userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async logout(userId: number, sessionId: string) {
    await this.revokeSession(userId, sessionId);
    return { message: 'Đăng xuất thành công' };
  }
}
