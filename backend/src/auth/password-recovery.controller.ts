import { Body, Controller, Post, Req } from '@nestjs/common';
import { PasswordRecoveryService } from './password-recovery.service';
import { RecoveryRequestDto, RecoveryVerifyDto, RecoveryResetDto } from './dto/password-recovery.dto';

@Controller('auth/password-recovery')
export class PasswordRecoveryController {
  constructor(private readonly recovery: PasswordRecoveryService) {}
  @Post('request')
  request(@Req() req: any, @Body() dto: RecoveryRequestDto) { this.recovery.limit(req.ip, 'request'); return this.recovery.request(dto.email); }
  @Post('verify')
  verify(@Req() req: any, @Body() dto: RecoveryVerifyDto) { this.recovery.limit(req.ip, 'verify'); return this.recovery.verify(dto.email, dto.code); }
  @Post('reset')
  reset(@Req() req: any, @Body() dto: RecoveryResetDto) { this.recovery.limit(req.ip, 'reset'); return this.recovery.reset(dto.email, dto.resetToken, dto.password); }
}
