import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Request,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { MatchesService } from './matches.service';
import { CreateOpenMatchDto, QueryOpenMatchDto } from './dto/open-match.dto';

@ApiTags('Open Match (Invitation & Participation)')
@Controller()
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  private extractUserId(req: any): number {
    const user = req.user || req.raw?.user;
    const id = user?.id ?? user?.sub ?? user?.userId;
    return Number(id);
  }

  @Post('bookings/:bookingId/open-match')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Mở một đơn đặt sân đã xác nhận thành Open Match để mời thêm người' })
  @ApiResponse({ status: 201, description: 'Mở Open Match thành công.' })
  @ApiResponse({ status: 403, description: 'Không phải người đã đặt sân này.' })
  createFromBooking(
    @Request() req: any,
    @Param('bookingId', ParseIntPipe) bookingId: number,
    @Body() dto: CreateOpenMatchDto,
  ) {
    const userId = this.extractUserId(req);
    return this.matchesService.createFromBooking(userId, bookingId, dto);
  }

  @Get('open-matches')
  @ApiOperation({ summary: 'Duyệt danh sách Open Match đang mở (Public)' })
  @ApiResponse({ status: 200, description: 'Danh sách Open Match.' })
  findAll(@Query() query: QueryOpenMatchDto) {
    return this.matchesService.findAll(query);
  }

  @Get('open-matches/:id')
  @ApiOperation({ summary: 'Xem chi tiết một Open Match, kèm danh sách người tham gia (Public)' })
  @ApiResponse({ status: 200, description: 'Chi tiết Open Match.' })
  @ApiResponse({ status: 404, description: 'Không tìm thấy Open Match.' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.matchesService.findOneOrThrow(id);
  }

  @Post('open-matches/:id/join')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Gửi yêu cầu tham gia một Open Match' })
  @ApiResponse({ status: 201, description: 'Gửi yêu cầu tham gia thành công.' })
  requestToJoin(@Request() req: any, @Param('id', ParseIntPipe) id: number) {
    const userId = this.extractUserId(req);
    return this.matchesService.requestToJoin(userId, id);
  }

  @Patch('open-matches/:id/participants/:participantId/accept')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Host duyệt (chấp nhận) một yêu cầu tham gia' })
  @ApiResponse({ status: 200, description: 'Duyệt yêu cầu thành công.' })
  @ApiResponse({ status: 403, description: 'Không phải host của trận đấu.' })
  accept(
    @Request() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('participantId', ParseIntPipe) participantId: number,
  ) {
    const userId = this.extractUserId(req);
    return this.matchesService.respondToRequest(userId, id, participantId, true);
  }

  @Patch('open-matches/:id/participants/:participantId/reject')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Host từ chối một yêu cầu tham gia' })
  @ApiResponse({ status: 200, description: 'Từ chối yêu cầu thành công.' })
  @ApiResponse({ status: 403, description: 'Không phải host của trận đấu.' })
  reject(
    @Request() req: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('participantId', ParseIntPipe) participantId: number,
  ) {
    const userId = this.extractUserId(req);
    return this.matchesService.respondToRequest(userId, id, participantId, false);
  }

  @Patch('open-matches/:id/leave')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  @ApiOperation({ summary: 'Rời khỏi Open Match (hoặc rút yêu cầu tham gia đang chờ)' })
  @ApiResponse({ status: 200, description: 'Rời trận đấu thành công.' })
  leave(@Request() req: any, @Param('id', ParseIntPipe) id: number) {
    const userId = this.extractUserId(req);
    return this.matchesService.leave(userId, id);
  }
}
