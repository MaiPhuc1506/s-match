import { Body, Controller, Get, Put, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Roles } from '../auth/roles.decorator.js';
import { RolesGuard } from '../auth/roles.guard.js';
import { Role } from '../auth/roles.enum.js';
import { PreferenceService } from './preference.service';
import { UpsertPreferenceDto } from './dto/preference.dto';

@ApiTags('Preference')
@Controller('preferences')
export class PreferenceController {
  constructor(private readonly preferenceService: PreferenceService) {}

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Xem sở thích chơi của tôi' })
  findMine(@Req() req: any) {
    return this.preferenceService.findForUser(req.user.sub);
  }

  @Put('me')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Tạo hoặc cập nhật sở thích chơi của tôi' })
  upsertMine(@Req() req: any, @Body() dto: UpsertPreferenceDto) {
    return this.preferenceService.upsert(req.user.sub, dto);
  }
}
