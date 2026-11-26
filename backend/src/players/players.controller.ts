import { Body, Controller, Get, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { PlayersService } from './players.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { InitialSkillQuizDto } from './dto/initial-skill-quiz.dto';

@ApiTags('Player Profile')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.PLAYER)
@Controller('players')
export class PlayersController {
  constructor(private readonly playersService: PlayersService) {}

  @Get('profile/me')
  @ApiOperation({ summary: 'Xem hồ sơ cá nhân của Player đang đăng nhập' })
  getMyProfile(@Req() req: any) {
    const userId = Number(req.user.sub);
    return this.playersService.getMyProfile(userId);
  }

  @Post('skill-assessment/initial')
  @ApiOperation({ summary: 'Submit a one-time initial skill estimate' })
  initialSkill(@Req() req: any, @Body() dto: InitialSkillQuizDto) {
    return this.playersService.submitInitialSkill(Number(req.user.sub), dto.answers);
  }

  @Patch('profile/me')
  @ApiOperation({ summary: 'Cập nhật hồ sơ cá nhân của Player đang đăng nhập' })
  updateMyProfile(@Req() req: any, @Body() dto: UpdateProfileDto) {
    const userId = Number(req.user.sub);
    return this.playersService.updateMyProfile(userId, dto);
  }
}