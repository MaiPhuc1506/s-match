import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { FacilitiesService } from './facilities.service';
import { CreateFacilityDto } from './dto/create-facility.dto';
import { CreateCourtDto } from './dto/create-court.dto';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';

@ApiTags('Facilities (Court Management)')
@Controller('facilities')
export class FacilitiesController {
  constructor(private readonly facilitiesService: FacilitiesService) {}

  @Post()
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân tạo cơ sở sân thể thao mới' })
  @ApiResponse({ status: 201, description: 'Tạo cơ sở thành công.' })
  @ApiResponse({ status: 403, description: 'Không có quyền (Chỉ COURT_OWNER/ADMIN).' })
  createFacility(@Req() req: any, @Body() dto: CreateFacilityDto) {
    const ownerId = Number(req.user.sub);
    return this.facilitiesService.createFacility(ownerId, dto);
  }

  @Get('my')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân lấy danh sách các cơ sở do mình quản lý' })
  @ApiResponse({ status: 200, description: 'Danh sách cơ sở của chủ sân.' })
  getMyFacilities(@Req() req: any) {
    const ownerId = Number(req.user.sub);
    return this.facilitiesService.getMyFacilities(ownerId);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem chi tiết cơ sở và danh sách sân con (Public)' })
  @ApiResponse({ status: 200, description: 'Thông tin chi tiết cơ sở.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy cơ sở.' })
  getFacilityById(@Param('id', ParseIntPipe) id: number) {
    return this.facilitiesService.getFacilityById(id);
  }

  @Post(':id/courts')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Chủ sân thêm sân cầu lông con vào cơ sở' })
  @ApiResponse({ status: 201, description: 'Thêm sân con thành công.' })
  @ApiResponse({ status: 403, description: 'Không có quyền can thiệp vào cơ sở này.' })
  addCourt(
    @Req() req: any,
    @Param('id', ParseIntPipe) facilityId: number,
    @Body() dto: CreateCourtDto,
  ) {
    const ownerId = Number(req.user.sub);
    return this.facilitiesService.addCourt(ownerId, facilityId, dto);
  }
}