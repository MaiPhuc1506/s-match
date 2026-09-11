import { Injectable, CanActivate, ExecutionContext, UnauthorizedException, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { ROLES_KEY } from './roles.decorator.js';
import { Role } from './roles.enum.js';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private jwtService: JwtService,
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

    const [type, token] = authHeader.split(' ');
    if (type !== 'Bearer' || !token) {
      throw new UnauthorizedException('Token không đúng định dạng Bearer');
    }

    try {
      const payload = await this.jwtService.verifyAsync(token, {
        secret: 's-match-super-secret-key',
      });
      request['user'] = payload;

      if (!requiredRoles) {
        return true;
      }

      // Chuẩn hóa về chữ thường để so sánh không bị lỗi hoa/thường
      const userRole = String(payload.role || '').toLowerCase();
      const hasRole = requiredRoles.some(
        (role) => String(role).toLowerCase() === userRole,
      );

      if (!hasRole) {
        throw new ForbiddenException('Bạn không có quyền truy cập chức năng này');
      }

      return true;
    } catch (error) {
      if (error instanceof ForbiddenException) {
        throw error;
      }
      throw new UnauthorizedException('Token không hợp lệ hoặc đã hết hạn');
    }
  }
}