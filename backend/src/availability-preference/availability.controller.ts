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
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { Role } from '../auth/roles.enum.js';
import { AvailabilityService } from './availability.service';
import { CreateAvailabilityDto, UpdateAvailabilityDto } from './dto/availability.dto';

@ApiTags('Availability')
@Controller('availability')
export class AvailabilityController {
  constructor(private readonly availabilityService: AvailabilityService) {}

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Xem danh sách khung giờ rảnh của tôi' })
  findMine(@Req() req: any) {
    return this.availabilityService.findAllForUser(req.user.sub);
  }

  @Post('me')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Thêm một khung giờ rảnh' })
  create(@Req() req: any, @Body() dto: CreateAvailabilityDto) {
    return this.availabilityService.create(req.user.sub, dto);
  }

  @Patch('me/:id')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Cập nhật một khung giờ rảnh' })
  update(
    @Req() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAvailabilityDto,
  ) {
    return this.availabilityService.update(req.user.sub, id, dto);
  }

  @Delete('me/:id')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Xoá một khung giờ rảnh' })
  remove(@Req() req: any, @Param('id', ParseIntPipe) id: number) {
    return this.availabilityService.remove(req.user.sub, id);
  }

  @Get(':userId/upcoming-slots')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @ApiOperation({
    summary:
      'Quy đổi lịch rảnh định kỳ thành các mốc giờ cụ thể (ISO datetime) cho N ngày tới — dùng cho Matchmaking Service (SMM-11)',
  })
  getUpcomingSlots(
    @Param('userId', ParseIntPipe) userId: number,
    @Query('days') days?: string,
  ) {
    const daysAhead = days ? Number(days) : 7;
    return this.availabilityService.getUpcomingTimeSlots(userId, daysAhead);
  }
}
