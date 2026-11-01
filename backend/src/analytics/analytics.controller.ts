import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { RolesGuard } from '../auth/roles.guard';
import { AnalyticsService } from './analytics.service';
import { AnalyticsQueryDto, RevenueTrendQueryDto } from './dto/analytics-query.dto';

@ApiTags('Revenue Analytics')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.OWNER, Role.ADMIN)
@Controller('analytics/revenue')
export class AnalyticsController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  private caller(req: any) {
    const user = req.user || req.raw?.user;
    return {
      userId: Number(user?.id ?? user?.sub ?? user?.userId),
      role: String(user?.role?.name || user?.role || user?.roleName || ''),
    };
  }

  @Get('overview')
  @ApiOperation({ summary: 'Tổng quan doanh thu, số đơn đặt sân và tỉ lệ lấp đầy' })
  @ApiResponse({ status: 200, description: 'revenue, totalBookings, byStatus, occupancyRate, ...' })
  @ApiResponse({ status: 400, description: 'Khoảng ngày không hợp lệ (sai định dạng, from > to, quá 366 ngày).' })
  @ApiResponse({ status: 403, description: 'Không có quyền xem cơ sở này.' })
  overview(@Request() req: any, @Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getOverview(this.caller(req), query);
  }

  @Get('trend')
  @ApiOperation({ summary: 'Chuỗi doanh thu / số đơn / giờ sân theo ngày, tuần hoặc tháng' })
  @ApiResponse({ status: 200, description: '{ granularity, totalRevenue, totalBookings, series[] }' })
  trend(@Request() req: any, @Query() query: RevenueTrendQueryDto) {
    return this.analyticsService.getRevenueTrend(this.caller(req), query);
  }

  @Get('court-utilization')
  @ApiOperation({ summary: 'Mức sử dụng từng sân (giờ đã bán / giờ khả dụng), xếp cao → thấp' })
  @ApiResponse({ status: 200, description: '{ courts[] }' })
  courtUtilization(@Request() req: any, @Query() query: AnalyticsQueryDto) {
    return this.analyticsService.getCourtUtilization(this.caller(req), query);
  }
}
