import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOkResponse, ApiOperation, ApiQuery, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { RolesGuard } from '../auth/roles.guard';
import { AnalyticsService } from './analytics.service';
import { GetAnalyticsQueryDto } from './dto/get-analytics-query.dto';
import { AnalyticsOverviewResponseDto, CourtPerformanceListResponseDto } from './dto/analytics-response.dto';

@ApiTags('Analytics')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Controller('analytics')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  @Get('owner/overview')
  @Roles(Role.OWNER)
  @ApiOperation({ summary: 'Owner xem dashboard analytics trong phạm vi các cơ sở mình sở hữu' })
  @ApiQuery({ type: GetAnalyticsQueryDto })
  @ApiOkResponse({ type: AnalyticsOverviewResponseDto })
  @ApiResponse({ status: 400, description: 'Query date range hoặc facilityId không hợp lệ.' })
  @ApiResponse({ status: 401, description: 'Thiếu hoặc sai access token/session.' })
  @ApiResponse({ status: 403, description: 'Không phải COURT_OWNER hoặc Facility không thuộc Owner.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy Facility được lọc.' })
  getOwnerOverview(@Request() req: { user: { sub: number } }, @Query() query: GetAnalyticsQueryDto) {
    return this.analyticsService.getOwnerOverview(req.user.sub, query);
  }

  @Get('admin/overview')
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: 'Admin xem dashboard analytics toàn hệ thống hoặc một Facility' })
  @ApiQuery({ type: GetAnalyticsQueryDto })
  @ApiOkResponse({ type: AnalyticsOverviewResponseDto })
  @ApiResponse({ status: 400, description: 'Query date range hoặc facilityId không hợp lệ.' })
  @ApiResponse({ status: 401, description: 'Thiếu hoặc sai access token/session.' })
  @ApiResponse({ status: 403, description: 'Không phải ADMIN.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy Facility được lọc.' })
  getAdminOverview(@Query() query: GetAnalyticsQueryDto) {
    return this.analyticsService.getAdminOverview(query);
  }

  @Get('courts/performance')
  @Roles(Role.OWNER, Role.ADMIN)
  @ApiOperation({ summary: 'Owner/Admin xem Court Performance trong phạm vi được cấp quyền' })
  @ApiQuery({ type: GetAnalyticsQueryDto })
  @ApiOkResponse({ type: CourtPerformanceListResponseDto })
  @ApiResponse({ status: 400, description: 'Query date range hoặc facilityId không hợp lệ.' })
  @ApiResponse({ status: 401, description: 'Thiếu hoặc sai access token/session.' })
  @ApiResponse({ status: 403, description: 'Không có quyền xem Court Performance của Facility này.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy Facility được lọc.' })
  getCourtPerformance(
    @Request() req: { user: { sub: number; role: 'COURT_OWNER' | 'ADMIN' } },
    @Query() query: GetAnalyticsQueryDto,
  ) {
    return this.analyticsService.getCourtPerformance({ id: req.user.sub, role: req.user.role }, query);
  }
}
