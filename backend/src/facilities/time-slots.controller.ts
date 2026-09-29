import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiQuery,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { TimeSlotsService } from './time-slots.service';
import { CreateTimeSlotDto, UpdateTimeSlotDto } from './dto/time-slot.dto';

@ApiTags('Facilities (Court Management)')
@Controller('facilities/:id/courts/:courtId/time-slots')
export class TimeSlotsController {
  constructor(private readonly timeSlotsService: TimeSlotsService) {}

  @Get()
  @ApiOperation({ summary: 'Xem tất cả khung giờ + giá của một sân (Public)' })
  @ApiResponse({ status: 200, description: 'Danh sách khung giờ định kỳ hàng tuần.' })
  findAll(
    @Param('id', ParseIntPipe) facilityId: number,
    @Param('courtId', ParseIntPipe) courtId: number,
  ) {
    return this.timeSlotsService.findAllForCourt(facilityId, courtId);
  }

  @Get('availability')
  @ApiOperation({ summary: 'Xem khung giờ + giá của sân cho một ngày cụ thể (Public)' })
  @ApiQuery({ name: 'date', example: '2026-10-05', description: 'YYYY-MM-DD' })
  @ApiResponse({ status: 200, description: 'Danh sách khung giờ khả dụng cho ngày đã chọn.' })
  getAvailability(
    @Param('id', ParseIntPipe) facilityId: number,
    @Param('courtId', ParseIntPipe) courtId: number,
    @Query('date') date: string,
  ) {
    return this.timeSlotsService.getAvailabilityForDate(facilityId, courtId, date);
  }

  @Post()
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân thêm khung giờ + giá cho sân' })
  @ApiResponse({ status: 201, description: 'Thêm khung giờ thành công.' })
  @ApiResponse({ status: 400, description: 'Khung giờ trùng hoặc nằm ngoài giờ hoạt động.' })
  @ApiResponse({ status: 403, description: 'Không có quyền can thiệp vào cơ sở này.' })
  create(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Param('courtId', ParseIntPipe) courtId: number,
    @Body() dto: CreateTimeSlotDto,
  ) {
    const ownerId = Number(req.user.sub);
    return this.timeSlotsService.create(ownerId, facilityId, courtId, dto);
  }

  @Patch(':slotId')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân cập nhật khung giờ/giá (hoặc tắt slot)' })
  @ApiResponse({ status: 200, description: 'Cập nhật khung giờ thành công.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy khung giờ.' })
  update(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Param('courtId', ParseIntPipe) courtId: number,
    @Param('slotId', ParseIntPipe) slotId: number,
    @Body() dto: UpdateTimeSlotDto,
  ) {
    const ownerId = Number(req.user.sub);
    return this.timeSlotsService.update(ownerId, facilityId, courtId, slotId, dto);
  }

  @Delete(':slotId')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân xoá khung giờ' })
  @ApiResponse({ status: 200, description: 'Xoá khung giờ thành công.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy khung giờ.' })
  remove(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Param('courtId', ParseIntPipe) courtId: number,
    @Param('slotId', ParseIntPipe) slotId: number,
  ) {
    const ownerId = Number(req.user.sub);
    return this.timeSlotsService.remove(ownerId, facilityId, courtId, slotId);
  }
}
