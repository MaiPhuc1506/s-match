import { Body, Controller, Get, Patch, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { PlayersService } from './players.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@ApiTags('Player Profile')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Controller('players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Get('profile/me')
  @ApiOperation({ summary: 'Xem hồ sơ cá nhân của Player đang đăng nhập' })
  getMyProfile(@Req() req: any) {
    const userId = Number(req.user.sub);
    return this.playersService.getMyProfile(userId);
  }

  @Patch('profile/me')
  @ApiOperation({ summary: 'Cập nhật hồ sơ cá nhân của Player đang đăng nhập' })
  updateMyProfile(@Req() req: any, @Body() dto: UpdateProfileDto) {
    const userId = Number(req.user.sub);
    return this.playersService.updateMyProfile(userId, dto);
  }
}