import { Body, Controller, HttpCode, Post, Request, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from './auth/roles.guard';
import { Roles } from './auth/roles.decorator';
import { Role } from './auth/roles.enum';
import { MatchmakingService } from './matchmaking.service';
import { FindPlayerDto } from './matchmaking/dto/find-player.dto';
import { MatchmakingResponseDto } from './matchmaking/dto/matchmaking-response.dto';

@ApiTags('Matchmaking')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.PLAYER)
@Controller('matchmaking')
export class MatchmakingController {
  constructor(private readonly matchmakingService: MatchmakingService) {}

  @Post('recommend')
  @HttpCode(200)
  @ApiOperation({ summary: 'Tìm người chơi; contract Flutter tạm thời của SMM-26' })
  @ApiResponse({ status: 200, type: MatchmakingResponseDto })
  @ApiResponse({ status: 400, description: 'Dữ liệu tìm kiếm không hợp lệ' })
  @ApiResponse({ status: 401, description: 'Chưa xác thực hoặc phiên không hợp lệ' })
  @ApiResponse({ status: 403, description: 'Chỉ PLAYER được sử dụng' })
  @ApiResponse({ status: 502, description: 'Dữ liệu/phản hồi dependency không hợp lệ' })
  @ApiResponse({ status: 503, description: 'Dependency chưa sẵn sàng' })
  @ApiResponse({ status: 504, description: 'Dependency phản hồi quá thời gian' })
  getRecommendations(@Request() req: { user: { sub: number } }, @Body() dto: FindPlayerDto) {
    return this.matchmakingService.getRecommendedMatches(req.user.sub, dto);
  }
}
