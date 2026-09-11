import { PrismaService } from '../prisma/prisma.service';
import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';

interface UserRecord {
  id: number;
  email: string;
  password: string;
  fullName: string;
  role: string;
  refreshToken?: string | null;
}

@Injectable()
export class AuthService {
  private readonly mockUsers: UserRecord[] = [];

  constructor(
  private readonly prisma: PrismaService,
  private readonly jwtService: JwtService,
) {}

  async register(registerDto: RegisterDto) {
    const existingUser = this.mockUsers.find((u) => u.email === registerDto.email);
    if (existingUser) {
      throw new BadRequestException('Email đã được sử dụng');
    }

    const hashedPassword = await bcrypt.hash(registerDto.password, 10);

    const newUser: UserRecord = {
      id: Date.now(),
      email: registerDto.email,
      password: hashedPassword,
      fullName: registerDto.fullName,
      role: 'Player',
      refreshToken: null,
    };
    this.mockUsers.push(newUser);

    return {
      message: 'Đăng ký thành công',
      data: {
        id: newUser.id,
        email: newUser.email,
        fullName: newUser.fullName,
        role: newUser.role,
      },
    };
  }

  async login(loginDto: LoginDto) {
  const user = await this.prisma.user.findUnique({
    where: { email: loginDto.email },
    include: { role: true },
  });

  if (!user) {
    throw new UnauthorizedException('Sai email hoặc mật khẩu');
  }

  const isPasswordValid = await bcrypt.compare(loginDto.password, user.password);
  if (!isPasswordValid) {
    throw new UnauthorizedException('Sai email hoặc mật khẩu');
  }

  const roleName = user.role?.name || 'PLAYER';
  const payload = { sub: user.id, email: user.email, role: roleName };
  
  // Tạo Access Token (15 phút) và Refresh Token (7 ngày)
  const accessToken = await this.jwtService.signAsync(payload, { expiresIn: '15m' });
  const refreshToken = await this.jwtService.signAsync(payload, { expiresIn: '7d' });

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
    try {
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: 's-match-super-secret-key',
      });

      const user = this.mockUsers.find((u) => u.id === payload.sub);
      if (!user || user.refreshToken !== refreshToken) {
        throw new UnauthorizedException('Refresh token không hợp lệ');
      }

      const newPayload = { sub: user.id, email: user.email, role: user.role };
      const newAccessToken = await this.jwtService.signAsync(newPayload, { expiresIn: '15m' });
      const newRefreshToken = await this.jwtService.signAsync(newPayload, { expiresIn: '7d' });

      user.refreshToken = newRefreshToken;

      return {
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      };
    } catch {
      throw new UnauthorizedException('Refresh token không hợp lệ hoặc đã hết hạn');
    }
  }

  async logout(userId: number) {
    const user = this.mockUsers.find((u) => u.id === userId);
    if (user) {
      user.refreshToken = null;
    }
    return { message: 'Đăng xuất thành công' };
  }
}