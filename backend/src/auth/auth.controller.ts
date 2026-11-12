import { Body, Controller, Post, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service.js';
import { RegisterDto } from './dto/register.dto.js';
import { LoginDto } from './dto/login.dto.js';
import { RefreshTokenDto } from './dto/refresh-token.dto.js';
import { RolesGuard } from './roles.guard.js';
import { Roles } from './roles.decorator.js';
import { Role } from './roles.enum.js';

@ApiTags('Authentication')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @ApiOperation({ summary: 'Đăng ký tài khoản người dùng' })
  @ApiResponse({ status: 201, description: 'Đăng ký tài khoản thành công.' })
  @ApiResponse({ status: 400, description: 'Email đã được sử dụng hoặc dữ liệu không hợp lệ.' })
  register(@Body() registerDto: RegisterDto) {
    return this.authService.register(registerDto);
  }

  @Post('login')
  @ApiOperation({ summary: 'Đăng nhập và nhận Token' })
  @ApiResponse({ status: 200, description: 'Đăng nhập thành công, trả về access token và refresh token.' })
  @ApiResponse({ status: 400, description: 'Email hoặc mật khẩu không chính xác.' })
  login(@Body() loginDto: LoginDto) {
    return this.authService.login(loginDto);
  }

  @Post('refresh')
  @ApiOperation({ summary: 'Cấp lại Access Token bằng Refresh Token' })
  @ApiResponse({ status: 200, description: 'Cấp mới token thành công.' })
  @ApiResponse({ status: 401, description: 'Refresh token không hợp lệ hoặc đã hết hạn.' })
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refreshTokens(dto.refreshToken);
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @ApiOperation({ summary: 'Đăng xuất tài khoản' })
  @ApiResponse({ status: 200, description: 'Đăng xuất thành công, thu hồi session.' })
  @ApiResponse({ status: 401, description: 'Chưa xác thực hoặc token không hợp lệ.' })
  logout(@Req() req: any) {
    return this.authService.logout(req.user.sub, req.user.sid);
  }

  @Get('admin-only')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'API kiểm tra quyền Admin' })
  @ApiResponse({ status: 200, description: 'Xác thực Admin thành công.' })
  @ApiResponse({ status: 403, description: 'Không có quyền Admin.' })
  testAdminOnly() {
    return {
      message: 'Chào mừng Admin, bạn đã truy cập thành công API được bảo vệ!',
    };
  }
}
