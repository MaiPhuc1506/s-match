import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { BookingsService } from './bookings.service';
import { CreateBookingDto } from './dto/create-booking.dto';
import { RolesGuard } from '../auth/roles.guard';

@ApiTags('Bookings')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Controller('bookings')
export class BookingsController {
  constructor(private readonly bookingsService: BookingsService) {}

  private extractUserId(req: any): number {
    const user = req.user || req.raw?.user;
    const id = user?.id ?? user?.sub ?? user?.userId;
    return Number(id);
  }

  private extractUserRole(req: any): string {
    const user = req.user || req.raw?.user;
    return user?.role?.name || user?.role || user?.roleName || 'PLAYER';
  }

  @Post()
  @ApiOperation({ summary: 'Tạo đơn đặt sân mới (kiểm tra chống trùng lịch)' })
  @ApiResponse({ status: 201, description: 'Đặt sân thành công.' })
  @ApiResponse({ status: 400, description: 'Dữ liệu thời gian hoặc sân không hợp lệ.' })
  @ApiResponse({ status: 409, description: 'Xung đột khung giờ (Double booking).' })
  async create(@Request() req: any, @Body() dto: CreateBookingDto) {
    const userId = this.extractUserId(req);
    return this.bookingsService.create(userId, dto);
  }

  @Get('my')
  @ApiOperation({ summary: 'Xem lịch sử danh sách đặt sân của tài khoản đang đăng nhập' })
  @ApiResponse({ status: 200, description: 'Danh sách đơn đặt sân.' })
  async findMyBookings(@Request() req: any) {
    const userId = this.extractUserId(req);
    return this.bookingsService.findMyBookings(userId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem chi tiết đơn đặt sân' })
  @ApiResponse({ status: 200, description: 'Chi tiết đơn đặt sân.' })
  @ApiResponse({ status: 403, description: 'Không có quyền truy cập.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy đơn đặt sân.' })
  async findOne(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    const userId = this.extractUserId(req);
    const role = this.extractUserRole(req);
    return this.bookingsService.findOne(id, userId, role);
  }

  @Patch(':id/cancel')
  @ApiOperation({ summary: 'Hủy đơn đặt sân' })
  @ApiResponse({ status: 200, description: 'Hủy đơn đặt sân thành công.' })
  @ApiResponse({ status: 400, description: 'Đơn đã hủy trước đó.' })
  @ApiResponse({ status: 403, description: 'Không có quyền hủy.' })
  async cancel(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    const userId = this.extractUserId(req);
    const role = this.extractUserRole(req);
    return this.bookingsService.cancel(id, userId, role);
  }
}