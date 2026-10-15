import { Body, Controller, Get, Put, Query, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { CandidatesService } from './candidates.service';
import { CandidateQueryDto, UpdateLocationDto } from './dto/candidate.dto';

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
      'Dựng sẵn body cho Matchmaking Service (POST /api/v1/match): current_user + candidates trong bán kính',
  })
  @ApiResponse({ status: 200, description: '{ request, meta } — gửi nguyên `request` sang Matchmaking Service.' })
  @ApiResponse({ status: 400, description: 'Chưa cập nhật vị trí.' })
  buildMatchmakingRequest(@Request() req: any, @Query() query: CandidateQueryDto) {
    return this.candidatesService.buildMatchmakingRequest(this.extractUserId(req), query);
  }
}
