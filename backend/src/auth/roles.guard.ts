import { Injectable, CanActivate, ExecutionContext, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthTokensService } from './auth-tokens.service';
import { PrismaService } from '../prisma/prisma.service';
import { ROLES_KEY } from './roles.decorator.js';
import { Role } from './roles.enum.js';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private tokens: AuthTokensService,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const requiredRoles = this.reflector.getAllAndOverride<Role[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader) {
      throw new UnauthorizedException('Thiếu token xác thực');
    }

    const parts = typeof authHeader === 'string' ? authHeader.split(' ') : [];
    const [type, token] = parts;
    if (parts.length !== 2 || type !== 'Bearer' || !token) {
      throw new UnauthorizedException('Token không đúng định dạng Bearer');
    }

    const payload = await this.tokens.verify(token, 'access');
    // Database errors remain infrastructure errors, not incorrect-token responses.
    const session = await this.prisma.refreshSession.findUnique({
      where: { id: payload.sid },
      select: {
        userId: true,
        expiresAt: true,
        revokedAt: true,
        user: { select: { id: true, email: true, role: { select: { name: true } } } },
      },
    });
    if (
      !session || session.userId !== payload.sub || session.revokedAt ||
      session.expiresAt <= new Date() || !session.user ||
      !Object.values(Role).includes(session.user.role?.name as Role)
    ) {
      throw new UnauthorizedException('Phiên đăng nhập không hợp lệ hoặc đã hết hạn');
    }
    request.user = { ...payload, email: session.user.email, role: session.user.role.name };
    if (requiredRoles && !requiredRoles.includes(request.user.role)) {
      throw new ForbiddenException('Bạn không có quyền truy cập chức năng này');
    }
    return true;
  }
}
