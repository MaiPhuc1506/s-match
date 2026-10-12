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
import { MatchesService } from './matches.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';
import { InviteUserDto } from './dto/participant-action.dto';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { Role } from '../auth/roles.enum';
import { CreateOpenMatchDto, QueryOpenMatchDto } from './dto/open-match.dto';

@ApiTags('Matches')
@ApiBearerAuth()
@UseGuards(RolesGuard)
@Controller('matches')
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  private extractUserId(req: any): number {
    const user = req.user || req.raw?.user;
    return Number(user?.id ?? user?.sub ?? user?.userId);
  }

  // --- MATCH LIFECYCLE ---

  @Post()
  @ApiOperation({ summary: 'Tạo trận đấu mới (Open hoặc Private)' })
  @ApiResponse({ status: 201, description: 'Tạo trận thành công.' })
  async createMatch(@Request() req: any, @Body() dto: CreateMatchDto) {
    const userId = this.extractUserId(req);
    return this.matchesService.createMatch(userId, dto);
  }

  @Get('open')
  @ApiOperation({ summary: 'Xem danh sách các kèo Open Match đang tìm người' })
  @ApiResponse({ status: 200, description: 'Danh sách trận đấu mở.' })
  async findOpenMatches() {
    return this.matchesService.findOpenMatches();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Xem chi tiết trận đấu và danh sách người tham gia' })
  @ApiResponse({ status: 200, description: 'Thông tin trận đấu.' })
  async findOne(@Param('id', ParseIntPipe) id: number) {
    return this.matchesService.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Cập nhật thông tin trận đấu (Chỉ Host)' })
  async updateMatch(
    @Param('id', ParseIntPipe) id: number,
    @Request() req: any,
    @Body() dto: UpdateMatchDto,
  ) {
    const userId = this.extractUserId(req);
    return this.matchesService.updateMatch(id, userId, dto);
  }

  @Patch(':id/cancel')
  @ApiOperation({ summary: 'Hủy trận đấu (Chỉ Host)' })
  async cancelMatch(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    const userId = this.extractUserId(req);
    return this.matchesService.cancelMatch(id, userId);
  }

  // --- INVITATIONS & JOIN REQUESTS ---

  @Post(':id/invite')
  @ApiOperation({ summary: 'Host gửi lời mời một người chơi tham gia trận' })
  async inviteUser(
    @Param('id', ParseIntPipe) id: number,
    @Request() req: any,
    @Body() dto: InviteUserDto,
  ) {
    const hostUserId = this.extractUserId(req);
    return this.matchesService.inviteUser(id, hostUserId, dto.targetUserId);
  }

  @Post(':id/join-request')
  @ApiOperation({ summary: 'Người chơi gửi yêu cầu xin tham gia Open Match' })
  async requestToJoin(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    const userId = this.extractUserId(req);
    return this.matchesService.requestToJoin(id, userId);
  }

  @Patch(':id/invitations/accept')
  @ApiOperation({ summary: 'Người chơi chấp nhận lời mời từ Host' })
  async acceptInvitation(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    const userId = this.extractUserId(req);
    return this.matchesService.acceptInvitation(id, userId);
  }

  @Patch(':id/invitations/reject')
  @ApiOperation({ summary: 'Người chơi từ chối lời mời từ Host' })
  async rejectInvitation(@Param('id', ParseIntPipe) id: number, @Request() req: any) {
    const userId = this.extractUserId(req);
    return this.matchesService.rejectInvitation(id, userId);
  }

  @Patch(':id/requests/:userId/approve')
  @ApiOperation({ summary: 'Host duyệt yêu cầu tham gia trận của người chơi' })
  async hostApproveRequest(
    @Param('id', ParseIntPipe) id: number,
    @Param('userId', ParseIntPipe) applicantUserId: number,
    @Request() req: any,
  ) {
    const hostUserId = this.extractUserId(req);
    return this.matchesService.hostApproveRequest(id, hostUserId, applicantUserId);
  }

  @Patch(':id/requests/:userId/reject')
  @ApiOperation({ summary: 'Host từ chối yêu cầu tham gia trận của người chơi' })
  async hostRejectRequest(
    @Param('id', ParseIntPipe) id: number,
    @Param('userId', ParseIntPipe) applicantUserId: number,
    @Request() req: any,
  ) {
    const hostUserId = this.extractUserId(req);
    return this.matchesService.hostRejectRequest(id, hostUserId, applicantUserId);
  }
}

@ApiTags('Open Match (Invitation & Participation)')
@Controller()
export class OpenMatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  private userId(request: any): number {
    const user = request.user || request.raw?.user;
    return Number(user?.id ?? user?.sub ?? user?.userId);
  }

  @Post('bookings/:bookingId/open-match')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  createFromBooking(
    @Request() request: any,
    @Param('bookingId', ParseIntPipe) bookingId: number,
    @Body() dto: CreateOpenMatchDto,
  ) {
    return this.matchesService.createFromBooking(this.userId(request), bookingId, dto);
  }

  @Get('open-matches')
  findAll(@Query() query: QueryOpenMatchDto) {
    return this.matchesService.findAll(query);
  }

  @Get('open-matches/:id')
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.matchesService.findOneOrThrow(id);
  }

  @Post('open-matches/:id/join')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  requestToJoin(@Request() request: any, @Param('id', ParseIntPipe) id: number) {
    return this.matchesService.requestToJoin(id, this.userId(request));
  }

  @Patch('open-matches/:id/participants/:participantId/accept')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  accept(
    @Request() request: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('participantId', ParseIntPipe) participantId: number,
  ) {
    return this.matchesService.respondToRequest(this.userId(request), id, participantId, true);
  }

  @Patch('open-matches/:id/participants/:participantId/reject')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  reject(
    @Request() request: any,
    @Param('id', ParseIntPipe) id: number,
    @Param('participantId', ParseIntPipe) participantId: number,
  ) {
    return this.matchesService.respondToRequest(this.userId(request), id, participantId, false);
  }

  @Patch('open-matches/:id/leave')
  @ApiBearerAuth()
  @UseGuards(RolesGuard)
  @Roles(Role.PLAYER)
  leave(@Request() request: any, @Param('id', ParseIntPipe) id: number) {
    return this.matchesService.leave(this.userId(request), id);
  }
}
