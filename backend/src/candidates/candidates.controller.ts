import { Body, Controller, Get, Put, Query, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { CandidatesService } from './candidates.service';
import { CandidateQueryDto, UpdateLocationDto, UpdateLocationSharingDto } from './dto/candidate.dto';

@ApiTags('Candidates (Geo Search & Matchmaking Data)')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.PLAYER)
@Controller('candidates')
export class CandidatesController {
  constructor(private readonly candidatesService: CandidatesService) {}

  private extractUserId(req: any): number {
    const user = req.user || req.raw?.user;
    return Number(user?.id ?? user?.sub ?? user?.userId);
  }

  @Put('me/location')
  @ApiOperation({ summary: 'Cập nhật vị trí hiện tại của tôi (dùng cho Geo Search / Matchmaking)' })
  @ApiResponse({ status: 200, description: 'Đã lưu vị trí.' })
  updateMyLocation(@Request() req: any, @Body() dto: UpdateLocationDto) {
    return this.candidatesService.updateMyLocation(this.extractUserId(req), dto);
  }

  @Get('me/location-sharing')
  @ApiOperation({ summary: 'Xem lựa chọn chia sẻ vị trí của tôi' })
  getLocationSharing(@Request() req: any) {
    return this.candidatesService.getLocationSharing(this.extractUserId(req));
  }

  @Put('me/location-sharing')
  @ApiOperation({ summary: 'Bật hoặc thu hồi quyền khám phá theo vị trí' })
  updateLocationSharing(@Request() req: any, @Body() dto: UpdateLocationSharingDto) {
    return this.candidatesService.updateLocationSharing(this.extractUserId(req), dto.enabled);
  }

  @Get('nearby')
  @ApiOperation({ summary: 'Tìm người chơi gần tôi trong bán kính (gần nhất trước)' })
  @ApiResponse({ status: 200, description: 'Danh sách người chơi kèm khoảng cách (km).' })
  @ApiResponse({ status: 400, description: 'Chưa cập nhật vị trí.' })
  findNearby(@Request() req: any, @Query() query: CandidateQueryDto) {
    return this.candidatesService.findNearby(this.extractUserId(req), query);
  }

  @Get('matchmaking-request')
  @ApiOperation({
    summary:
      'Xem dữ liệu matchmaking an toàn; tọa độ ứng viên chỉ dùng nội bộ',
  })
  @ApiResponse({ status: 200, description: '{ request, meta } — không chứa tọa độ của ứng viên.' })
  @ApiResponse({ status: 400, description: 'Chưa cập nhật vị trí.' })
  async buildMatchmakingRequest(@Request() req: any, @Query() query: CandidateQueryDto) {
    const result = await this.candidatesService.buildMatchmakingRequest(this.extractUserId(req), query);
    return {
      ...result,
      request: {
        ...result.request,
        candidates: result.request.candidates.map(({ location: _location, ...candidate }) => candidate),
      },
    };
  }
}
