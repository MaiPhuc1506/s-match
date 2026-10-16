import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  InternalServerErrorException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';
import { BookingStatus, MatchPrivacy, MatchState, ParticipantRole, ParticipantStatus, Prisma } from '@prisma/client';
import { CreateOpenMatchDto, QueryOpenMatchDto } from './dto/open-match.dto';
import { Role } from '../auth/roles.enum';
import { types } from 'node:util';
import {
  MATCH_INVITATION_SELECT, MATCH_MANAGER_SELECT, MATCH_MEMBER_SELECT,
  MATCH_PUBLIC_SELECT, MATCH_PARTICIPANT_MUTATION_SELECT, toMatchResponse,
} from './match-response.select';

export interface MatchActor {
  id: number;
  role: Role;
}

@Injectable()
export class MatchesService {
  constructor(private readonly prisma: PrismaService) {}

  private validateMatchTimes(startValue: string | Date, endValue: string | Date) {
    const parse = (value: string | Date) => types.isDate(value)
      ? new Date(value.getTime())
      : typeof value === 'string' ? new Date(value) : new Date(NaN);
    const start = parse(startValue);
    const end = parse(endValue);
    if (!Number.isFinite(start.getTime()) || !Number.isFinite(end.getTime()) || start >= end) {
      throw new BadRequestException('Thời gian trận đấu không hợp lệ: bắt đầu phải trước kết thúc');
    }
    return { start, end };
  }

  private validatePlayerCount(value: unknown, minimum: number, maximum: number, field: string) {
    if (typeof value !== 'number' || !Number.isInteger(value) || value < minimum || value > maximum) {
      throw new BadRequestException(`${field} phải là số nguyên từ ${minimum} đến ${maximum}`);
    }
  }

  private requireOpenForAcceptance(status: MatchState) {
    if (status !== MatchState.OPEN) {
      throw new ConflictException('Trận đấu không ở trạng thái cho phép nhận thêm thành viên');
    }
  }

  private assertBookingId(bookingId: unknown): asserts bookingId is number {
    if (typeof bookingId !== 'number' || !Number.isInteger(bookingId) || bookingId < 1 || bookingId > 2147483647) {
      throw new BadRequestException('bookingId phải là số nguyên từ 1 đến 2147483647');
    }
  }

  private async requireHostBooking(
    db: Pick<Prisma.TransactionClient, 'booking' | '$queryRaw'>,
    bookingId: number,
    hostId: number,
    currentMatchId?: number,
  ) {
    this.assertBookingId(bookingId);
    // Called only inside an attachment transaction. FOR SHARE permits competing
    // attachment checks, but blocks cancellation/ownership updates or deletion
    // until the Match write commits. The unique index resolves competing links.
    await db.$queryRaw`SELECT id FROM "Booking" WHERE id = ${bookingId} FOR SHARE`;
    const booking = await db.booking.findUnique({
      where: { id: bookingId },
      select: {
        id: true, userId: true, status: true,
        match: { select: { id: true } },
        startTime: true, endTime: true, totalPrice: true,
        court: { select: { facility: { select: { name: true } } } },
      },
    });
    if (!booking) throw new NotFoundException('Không tìm thấy đơn đặt sân');
    if (booking.userId !== hostId) {
      throw new ForbiddenException('Bạn không có quyền sử dụng đơn đặt sân này');
    }
    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new ConflictException('Đơn đặt sân không ở trạng thái có thể liên kết');
    }
    if (booking.match && booking.match.id !== currentMatchId) {
      throw new ConflictException('Đơn đặt sân đã được liên kết với trận đấu khác');
    }
    return booking;
  }

  private rethrowMatchWriteError(error: unknown): never {
    if (error instanceof Prisma.PrismaClientKnownRequestError) {
      const target = error.meta?.target;
      const bookingConflict = Array.isArray(target)
        ? target.includes('bookingId')
        : typeof target === 'string' && /(?:^|_)bookingId(?:_|$)/.test(target);
      if (error.code === 'P2002' && bookingConflict) {
        throw new ConflictException('Đơn đặt sân đã được liên kết với trận đấu khác');
      }
      if (error.code === 'P2025') throw new NotFoundException('Không tìm thấy trận đấu');
      if (error.code === 'P2034') throw new ConflictException('Dữ liệu liên kết đang có xung đột');
      // Never include Prisma metadata, constraint details or query text in HTTP errors.
      throw new InternalServerErrorException('Không thể lưu trận đấu');
    }
    throw error;
  }

  async createFromBooking(hostUserId: number, bookingId: number, dto: CreateOpenMatchDto) {
    this.assertBookingId(bookingId);
    this.validatePlayerCount(dto.neededPlayers, 1, 2147483646, 'neededPlayers');
    try {
      return await this.prisma.$transaction(async (tx) => {
        const booking = await this.requireHostBooking(tx, bookingId, hostUserId);
        this.validateMatchTimes(booking.startTime, booking.endTime);
        if (dto.minSkillLevel > dto.maxSkillLevel) {
          throw new BadRequestException('minSkillLevel không được lớn hơn maxSkillLevel');
        }

        const maxPlayers = dto.neededPlayers + 1;
        const match = await tx.match.create({
          data: {
            title: `Open Match - ${booking.court.facility.name}`,
            privacy: MatchPrivacy.OPEN,
            status: MatchState.OPEN,
            hostId: hostUserId,
            bookingId,
            startTime: booking.startTime,
            endTime: booking.endTime,
            location: booking.court.facility.name,
            maxPlayers,
            feePerPlayer: booking.totalPrice / maxPlayers,
            mode: dto.mode,
            purpose: dto.purpose,
            minSkillLevel: dto.minSkillLevel,
            maxSkillLevel: dto.maxSkillLevel,
            participants: {
              create: { userId: hostUserId, role: ParticipantRole.HOST, status: ParticipantStatus.ACCEPTED },
            },
          },
          select: MATCH_MANAGER_SELECT,
        });
        return toMatchResponse(match);
      });
    } catch (error) {
      this.rethrowMatchWriteError(error);
    }
  }

  async findAll(query: QueryOpenMatchDto) {
    const matches = await this.prisma.match.findMany({
      where: {
        privacy: MatchPrivacy.OPEN,
        status: MatchState.OPEN,
        ...(query.mode && { mode: query.mode }),
        ...(query.purpose && { purpose: query.purpose }),
      },
      select: MATCH_PUBLIC_SELECT,
      orderBy: { createdAt: 'desc' },
    });
    return matches.map(toMatchResponse);
  }

  async findOneOrThrow(id: number) {
    const match = await this.prisma.match.findFirst({
      where: { id, privacy: MatchPrivacy.OPEN }, select: MATCH_PUBLIC_SELECT,
    });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    return toMatchResponse(match);
  }

  async respondToRequest(hostUserId: number, matchId: number, participantId: number, accept: boolean) {
    const match = await this.getMatchForParticipation(matchId);
    if (match.hostId !== hostUserId) {
      throw new ForbiddenException('Chỉ host mới có quyền duyệt yêu cầu tham gia');
    }
    const participant = match.participants.find((entry) => entry.id === participantId);
    if (!participant) {
      throw new NotFoundException(`Không tìm thấy yêu cầu tham gia ID ${participantId}`);
    }
    if (participant.status !== ParticipantStatus.REQUESTED) {
      throw new BadRequestException('Yêu cầu này đã được xử lý trước đó');
    }
    return accept
      ? this.hostApproveRequest(matchId, hostUserId, participant.userId)
      : this.hostRejectRequest(matchId, hostUserId, participant.userId);
  }

  async leave(userId: number, matchId: number) {
    const match = await this.getMatchForParticipation(matchId);
    if (match.hostId === userId) {
      throw new BadRequestException('Host không thể rời trận đấu của mình');
    }
    const participant = match.participants.find((entry) => entry.userId === userId);
    if (!participant || (
      participant.status !== ParticipantStatus.REQUESTED &&
      participant.status !== ParticipantStatus.INVITED &&
      participant.status !== ParticipantStatus.ACCEPTED
    )) {
      throw new NotFoundException('Bạn không có lời mời hoặc yêu cầu tham gia đang hoạt động');
    }
    await this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.CANCELLED },
    });
    await this.checkAndUpdateMatchFullState(matchId);
    // Membership has been removed; do not return PRIVATE detail after leaving.
    return { id: matchId, left: true };
  }

  // 1. Tạo Match mới (Người tạo tự động thành HOST và status ACCEPTED)
  async createMatch(userId: number, dto: CreateMatchDto) {
    const { start, end } = this.validateMatchTimes(dto.startTime, dto.endTime);
    if (dto.maxPlayers !== undefined) this.validatePlayerCount(dto.maxPlayers, 2, 2147483647, 'maxPlayers');

    if (dto.bookingId !== undefined) this.assertBookingId(dto.bookingId);

    try {
      return await this.prisma.$transaction(async (tx) => {
        if (dto.bookingId !== undefined) await this.requireHostBooking(tx, dto.bookingId, userId);
        const match = await tx.match.create({
          data: {
            title: dto.title,
            description: dto.description,
            privacy: (dto.privacy as MatchPrivacy) || MatchPrivacy.OPEN,
            bookingId: dto.bookingId,
            startTime: start,
            endTime: end,
            location: dto.location,
            maxPlayers: dto.maxPlayers || 4,
            feePerPlayer: dto.feePerPlayer || 0,
            hostId: userId,
            status: MatchState.OPEN,
            participants: {
              create: {
                userId,
                role: ParticipantRole.HOST,
                status: ParticipantStatus.ACCEPTED,
              },
            },
          },
          select: MATCH_MANAGER_SELECT,
        });

        return toMatchResponse(match);
      });
    } catch (error) {
      this.rethrowMatchWriteError(error);
    }
  }

  // 2. Lấy danh sách Open Matches để tìm kèo
  async findOpenMatches() {
    const matches = await this.prisma.match.findMany({
      where: {
        privacy: MatchPrivacy.OPEN,
        status: { in: [MatchState.OPEN, MatchState.FULL] },
      },
      select: MATCH_PUBLIC_SELECT,
      orderBy: { startTime: 'asc' },
    });
    return matches.map(toMatchResponse);
  }

  // 3. Xem chi tiết Match
  async findOne(id: number, actor: MatchActor) {
    const access = await this.prisma.match.findUnique({
      where: { id },
      select: {
        hostId: true,
        privacy: true,
        participants: {
          where: { userId: actor.id }, select: { status: true },
        },
      },
    });
    if (!access) throw new NotFoundException('Không tìm thấy trận đấu');

    const membership = access.participants[0]?.status;
    let select: Prisma.MatchSelect;
    let visibility: Prisma.MatchWhereInput;
    if (actor.role === Role.ADMIN || access.hostId === actor.id) {
      select = MATCH_MANAGER_SELECT;
      visibility = actor.role === Role.ADMIN ? {} : { hostId: actor.id };
    } else if (membership === ParticipantStatus.ACCEPTED) {
      select = MATCH_MEMBER_SELECT;
      visibility = { participants: { some: { userId: actor.id, status: ParticipantStatus.ACCEPTED } } };
    } else if (access.privacy === MatchPrivacy.PRIVATE && membership === ParticipantStatus.INVITED) {
      select = MATCH_INVITATION_SELECT;
      visibility = { participants: { some: { userId: actor.id, status: ParticipantStatus.INVITED } } };
    } else if (access.privacy === MatchPrivacy.OPEN) {
      select = MATCH_PUBLIC_SELECT;
      visibility = { privacy: MatchPrivacy.OPEN };
    } else {
      throw new ForbiddenException('Bạn không có quyền xem trận đấu này');
    }

    // Recheck visibility in the response query to avoid stale authorization.
    const match = await this.prisma.match.findUnique({
      where: { id, AND: visibility }, select,
    });
    if (!match) {
      const exists = await this.prisma.match.findUnique({ where: { id }, select: { id: true } });
      if (!exists) throw new NotFoundException('Không tìm thấy trận đấu');
      throw new ForbiddenException('Bạn không có quyền xem trận đấu này');
    }
    if (select === MATCH_INVITATION_SELECT) return match;
    return toMatchResponse(match);
  }

  private async getMatchForParticipation(id: number) {
    const match = await this.prisma.match.findUnique({
      where: { id },
      select: {
        id: true, hostId: true,
        participants: { select: { id: true, userId: true, status: true } },
      },
    });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    return match;
  }

  // 4. Cập nhật thông tin Match (Chỉ Host)
  async updateMatch(matchId: number, userId: number, dto: UpdateMatchDto) {
    if (dto.maxPlayers !== undefined) this.validatePlayerCount(dto.maxPlayers, 2, 2147483647, 'maxPlayers');
    // Validate an explicit null as well: detaching a Booking is not allowed.
    if (dto.bookingId !== undefined) this.assertBookingId(dto.bookingId);
    try {
      if (dto.bookingId !== undefined) {
        return await this.prisma.$transaction((tx) => this.updateMatchForHost(tx, matchId, userId, dto));
      }
      return await this.updateMatchForHost(this.prisma, matchId, userId, dto);
    } catch (error) {
      this.rethrowMatchWriteError(error);
    }
  }

  private async updateMatchForHost(db: Prisma.TransactionClient, matchId: number, userId: number, dto: UpdateMatchDto) {
    const match = await db.match.findUnique({
      where: { id: matchId }, select: { id: true, hostId: true, bookingId: true, startTime: true, endTime: true },
    });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== userId) {
      throw new ForbiddenException('Chỉ có Host mới có quyền chỉnh sửa trận đấu');
    }

    // Validate only when a time field is supplied; legacy times do not block title-only PATCH.
    if (dto.startTime !== undefined || dto.endTime !== undefined) {
      this.validateMatchTimes(
        dto.startTime !== undefined ? dto.startTime : match.startTime,
        dto.endTime !== undefined ? dto.endTime : match.endTime,
      );
    }

    if (dto.bookingId !== undefined) {
      await this.requireHostBooking(db, dto.bookingId, match.hostId, match.id);
    }

    // Only allow DTO fields. Internal callers cannot inject hostId, userId or relations.
    // Omitted/undefined fields are never written; explicit nullable scalars are.
    const data: Prisma.MatchUncheckedUpdateInput = Object.fromEntries(
      ['title', 'description', 'privacy', 'location', 'maxPlayers', 'feePerPlayer', 'startTime', 'endTime']
        .filter((key) => Object.prototype.hasOwnProperty.call(dto, key) && dto[key as keyof UpdateMatchDto] !== undefined)
        .map((key) => [key, dto[key as keyof UpdateMatchDto]]),
    );
    if (dto.bookingId !== undefined && dto.bookingId !== match.bookingId) data.bookingId = dto.bookingId;
    if (data.startTime !== undefined) data.startTime = new Date(dto.startTime!);
    if (data.endTime !== undefined) data.endTime = new Date(dto.endTime!);

    // A repeated bookingId by itself is a validated no-op.
    if (Object.keys(data).length === 0) {
      const unchanged = await db.match.findUnique({
        where: { id: matchId, hostId: match.hostId }, select: MATCH_MANAGER_SELECT,
      });
      if (!unchanged) throw new NotFoundException('Không tìm thấy trận đấu');
      return toMatchResponse(unchanged);
    }
    const updated = await db.match.update({
      where: { id: matchId, hostId: match.hostId }, data, select: MATCH_MANAGER_SELECT,
    });
    return toMatchResponse(updated);
  }

  // 5. Hủy Match (Chỉ Host)
  async cancelMatch(matchId: number, userId: number) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== userId) {
      throw new ForbiddenException('Chỉ có Host mới có quyền hủy trận đấu');
    }

    const cancelled = await this.prisma.match.update({
      where: { id: matchId },
      data: { status: MatchState.CANCELLED },
      select: MATCH_MANAGER_SELECT,
    });
    return toMatchResponse(cancelled);
  }

  // 6. Host mời thành viên vào trận
  async inviteUser(matchId: number, hostUserId: number, targetUserId: number) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { participants: true },
    });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== hostUserId) {
      throw new ForbiddenException('Chỉ có Host mới có quyền gửi lời mời');
    }

    const existing = match.participants.find((p: any) => p.userId === targetUserId);
    if (existing) {
      if (existing.status === ParticipantStatus.ACCEPTED) {
        throw new BadRequestException('Người chơi này đã tham gia trận');
      }
      return this.prisma.matchParticipant.update({
        where: { id: existing.id },
        data: { status: ParticipantStatus.INVITED },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });
    }

    return this.prisma.matchParticipant.create({
      data: {
        matchId,
        userId: targetUserId,
        role: ParticipantRole.MEMBER,
        status: ParticipantStatus.INVITED,
      },
      select: MATCH_PARTICIPANT_MUTATION_SELECT,
    });
  }

  // 7. Người chơi xin vào Open Match
  async requestToJoin(matchId: number, userId: number) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: {
        participants: { where: { status: ParticipantStatus.ACCEPTED } },
      },
    });

    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.status !== MatchState.OPEN) {
      throw new BadRequestException('Trận đấu này hiện không mở để tham gia');
    }
    if (match.privacy === MatchPrivacy.PRIVATE) {
      throw new BadRequestException('Đây là trận đấu kín (Private), cần có lời mời từ Host');
    }
    if (match.participants.length >= match.maxPlayers) {
      throw new BadRequestException('Trận đấu đã đủ số lượng người chơi');
    }

    const existing = await this.prisma.matchParticipant.findUnique({
      where: { matchId_userId: { matchId, userId } },
    });

    if (existing) {
      if (existing.status === ParticipantStatus.ACCEPTED) {
        throw new BadRequestException('Bạn đã là thành viên của trận này');
      }
      return this.prisma.matchParticipant.update({
        where: { id: existing.id },
        data: { status: ParticipantStatus.REQUESTED },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });
    }

    return this.prisma.matchParticipant.create({
      data: {
        matchId,
        userId,
        role: ParticipantRole.MEMBER,
        status: ParticipantStatus.REQUESTED,
      },
      select: MATCH_PARTICIPANT_MUTATION_SELECT,
    });
  }

  // 8. Chấp nhận lời mời (Accept Invitation)
  async acceptInvitation(matchId: number, userId: number) {
    const participant = await this.prisma.matchParticipant.findUnique({
      where: { matchId_userId: { matchId, userId } },
      include: { match: { include: { participants: { where: { status: ParticipantStatus.ACCEPTED } } } } },
    });

    if (!participant || participant.status !== ParticipantStatus.INVITED) {
      throw new BadRequestException('Không tìm thấy lời mời hợp lệ');
    }

    this.requireOpenForAcceptance(participant.match.status);
    if (participant.match.participants.length >= participant.match.maxPlayers) {
      throw new BadRequestException('Trận đấu đã đầy người chơi');
    }

    const updated = await this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.ACCEPTED },
      select: MATCH_PARTICIPANT_MUTATION_SELECT,
    });

    await this.checkAndUpdateMatchFullState(matchId);
    return updated;
  }

  // 9. Từ chối lời mời (Reject Invitation)
  async rejectInvitation(matchId: number, userId: number) {
    const participant = await this.prisma.matchParticipant.findUnique({
      where: { matchId_userId: { matchId, userId } },
    });

    if (!participant || participant.status !== ParticipantStatus.INVITED) {
      throw new BadRequestException('Không tìm thấy lời mời hợp lệ');
    }

    return this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.REJECTED },
      select: MATCH_PARTICIPANT_MUTATION_SELECT,
    });
  }

  // 10. Host duyệt yêu cầu xin vào trận
  async hostApproveRequest(matchId: number, hostUserId: number, applicantUserId: number) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { participants: { where: { status: ParticipantStatus.ACCEPTED } } },
    });

    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== hostUserId) {
      throw new ForbiddenException('Chỉ Host mới có quyền duyệt yêu cầu');
    }
    this.requireOpenForAcceptance(match.status);
    if (match.participants.length >= match.maxPlayers) {
      throw new BadRequestException('Trận đấu đã đủ người chơi');
    }

    const participant = await this.prisma.matchParticipant.findUnique({
      where: { matchId_userId: { matchId, userId: applicantUserId } },
    });

    if (!participant || participant.status !== ParticipantStatus.REQUESTED) {
      throw new BadRequestException('Không tìm thấy yêu cầu tham gia hợp lệ của người này');
    }

    const updated = await this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.ACCEPTED },
      select: MATCH_PARTICIPANT_MUTATION_SELECT,
    });

    await this.checkAndUpdateMatchFullState(matchId);
    return updated;
  }

  // 11. Host từ chối yêu cầu xin vào trận
  async hostRejectRequest(matchId: number, hostUserId: number, applicantUserId: number) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== hostUserId) {
      throw new ForbiddenException('Chỉ Host mới có quyền từ chối yêu cầu');
    }

    const participant = await this.prisma.matchParticipant.findUnique({
      where: { matchId_userId: { matchId, userId: applicantUserId } },
    });

    if (!participant || participant.status !== ParticipantStatus.REQUESTED) {
      throw new BadRequestException('Không tìm thấy yêu cầu tham gia hợp lệ của người này');
    }

    return this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.REJECTED },
      select: MATCH_PARTICIPANT_MUTATION_SELECT,
    });
  }

  private async checkAndUpdateMatchFullState(matchId: number) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: {
        booking: true,
        participants: { where: { status: ParticipantStatus.ACCEPTED } },
      },
    });

    if (!match || (match.status !== MatchState.OPEN && match.status !== MatchState.FULL)) return;
    await this.prisma.match.update({
      where: { id: matchId },
      data: {
        status: match.participants.length >= match.maxPlayers ? MatchState.FULL : MatchState.OPEN,
        ...(match.booking && { feePerPlayer: match.booking.totalPrice / Math.max(1, match.participants.length) }),
      },
    });
  }
}
