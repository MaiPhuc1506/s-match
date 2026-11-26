import {
  Body,
  Controller,
  HttpCode,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { AiService } from './ai.service';
import { AiChatRequestDto, AiChatResponseDto } from './dto/ai-chat.dto';

@ApiTags('Smash Scot AI Assistant')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Roles(Role.PLAYER, Role.OWNER, Role.ADMIN)
@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('chat')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'Chat with Smash Scot role-aware read-only AI assistant (JWT protected)',
  })
  @ApiResponse({ status: 200, type: AiChatResponseDto })
  @ApiResponse({ status: 400, description: 'Invalid message or history payload.' })
  @ApiResponse({ status: 401, description: 'Missing or invalid Bearer JWT session.' })
  @ApiResponse({ status: 429, description: 'Rate limit exceeded.' })
  chat(
    @Request() req: { user: { sub: number; role: Role } },
    @Body() dto: AiChatRequestDto,
  ): Promise<AiChatResponseDto> {
    return this.aiService.chat(
      {
        userId: Number(req.user.sub),
        role: req.user.role,
      },
      dto,
    );
  }
}
