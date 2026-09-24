import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Put,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { OperatingHoursService } from './operating-hours.service';
import {
  BulkUpsertOperatingHoursDto,
  UpsertOperatingHourDto,
} from './dto/operating-hours.dto';

@ApiTags('Facilities (Court Management)')
@Controller('facilities/:id/operating-hours')
export class OperatingHoursController {
  constructor(private readonly operatingHoursService: OperatingHoursService) {}

  @Get()
  @ApiOperation({ summary: 'Xem giờ hoạt động của một cơ sở (Public)' })
  @ApiResponse({ status: 200, description: 'Danh sách giờ hoạt động theo từng ngày trong tuần.' })
  findAll(@Param('id', ParseIntPipe) facilityId: number) {
    return this.operatingHoursService.findAllForFacility(facilityId);
  }

  @Put()
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân cập nhật giờ hoạt động cho một ngày trong tuần' })
  @ApiResponse({ status: 200, description: 'Cập nhật giờ hoạt động thành công.' })
  @ApiResponse({ status: 403, description: 'Không có quyền cập nhật cơ sở này.' })
  upsertOne(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Body() dto: UpsertOperatingHourDto,
  ) {
    const ownerId = Number(req.user.sub);
    return this.operatingHoursService.upsertOne(ownerId, facilityId, dto);
  }

  @Put('bulk')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân cập nhật giờ hoạt động cho nhiều ngày cùng lúc' })
  @ApiResponse({ status: 200, description: 'Cập nhật giờ hoạt động thành công.' })
  @ApiResponse({ status: 403, description: 'Không có quyền cập nhật cơ sở này.' })
  upsertBulk(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Body() dto: BulkUpsertOperatingHoursDto,
  ) {
    const ownerId = Number(req.user.sub);
    return this.operatingHoursService.upsertBulk(ownerId, facilityId, dto);
  }

  @Delete(':dayOfWeek')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân xoá giờ hoạt động của một ngày (đóng cửa ngày đó)' })
  @ApiResponse({ status: 200, description: 'Xoá giờ hoạt động thành công.' })
  @ApiResponse({ status: 404, description: 'Chưa có giờ hoạt động cho ngày này.' })
  remove(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Param('dayOfWeek', ParseIntPipe) dayOfWeek: number,
  ) {
    const ownerId = Number(req.user.sub);
    return this.operatingHoursService.remove(ownerId, facilityId, dayOfWeek);
  }
}
