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
import { SubmitFeedbackDto } from './dto/submit-feedback.dto';
import { FeedbackResponseDto } from './dto/feedback-response.dto';
import { eligibleNearbyInvite, invitationProfileSelect } from './invitation-eligibility';
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

  notifications(userId: number) {
    return this.prisma.matchNotification.findMany({ where: { userId }, orderBy: { createdAt: 'desc' }, take: 100 });
  }

  async markNotificationRead(userId: number, id: number) {
    const updated = await this.prisma.matchNotification.updateMany({ where: { id, userId }, data: { isRead: true } });
    if (!updated.count) throw new NotFoundException('Notification not found');
    return { id, isRead: true };
  }

  // All mutations of an existing Match/its roster take the same parent lock.
  // Completion therefore cannot commit between a state check and a roster write.
  private async withMatchLock<T>(matchId: number, action: (db: Prisma.TransactionClient) => Promise<T>): Promise<T> {
    try {
      return await this.prisma.$transaction(async (db) => {
        await db.$queryRaw`SELECT id FROM "Match" WHERE id = ${matchId} FOR UPDATE`;
        return action(db);
      }, { isolationLevel: Prisma.TransactionIsolationLevel.ReadCommitted });
    } catch (error) {
      this.rethrowMatchWriteError(error);
    }
  }

  private requireNotCompleted(status: MatchState) {
    if (status === MatchState.COMPLETED) {
      throw new ConflictException('Không thể thay đổi trận đấu đã hoàn thành');
    }
  }

  async completeMatch(matchId: number, userId: number) {
    if (!Number.isInteger(matchId) || matchId < 1 || matchId > 2147483647) {
      throw new BadRequestException('Match ID phải là số nguyên từ 1 đến 2147483647');
    }
    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({
        where: { id: matchId }, select: {
          hostId: true, status: true, startTime: true,
          participants: { where: { status: ParticipantStatus.ACCEPTED }, select: { userId: true } },
        },
      });
      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      if (match.hostId !== userId) throw new ForbiddenException('Chỉ Host mới có quyền hoàn thành trận đấu');
      const now = new Date();
      const allowed: MatchState[] = [MatchState.OPEN, MatchState.FULL, MatchState.IN_PROGRESS];
      if (!allowed.includes(match.status) || match.startTime > now) {
        throw new ConflictException('Trận đấu chưa đủ điều kiện hoàn thành');
      }
      const written = await db.match.updateMany({
        where: { id: matchId, hostId: userId, status: { in: allowed }, startTime: { lte: now } },
        data: { status: MatchState.COMPLETED },
      });
      if (written.count !== 1) throw new ConflictException('Trạng thái trận đấu đã thay đổi');
      // Persist delivery intent in the same transaction as completion.
      for (const participant of match.participants) {
        if (participant.userId === userId) continue;
        await db.matchNotification.create({
          data: { userId: participant.userId, matchId, kind: 'MATCH_COMPLETED' },
        });
      }
      const completed = await db.match.findUnique({ where: { id: matchId }, select: MATCH_MANAGER_SELECT });
      if (!completed) throw new NotFoundException('Không tìm thấy trận đấu');
      return toMatchResponse(completed);
    });
  }

  async submitFeedback(matchId: number, senderUserId: number, dto: SubmitFeedbackDto): Promise<FeedbackResponseDto> {
    this.validatePlayerCount(matchId, 1, 2147483647, 'Match ID');
    this.validatePlayerCount(dto.recipientUserId, 1, 2147483647, 'recipientUserId');
    this.validatePlayerCount(dto.rating, 1, 5, 'rating');
    if (dto.comment !== undefined && (typeof dto.comment !== 'string' || Array.from(dto.comment).length > 500)) {
      throw new BadRequestException('Comment phải là chuỗi tối đa 500 ký tự');
    }
    if (senderUserId === dto.recipientUserId) throw new BadRequestException('Không thể tự đánh giá');

    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({
        where: { id: matchId },
        select: {
          status: true, startTime: true,
          participants: {
            where: { userId: { in: [senderUserId, dto.recipientUserId] }, status: ParticipantStatus.ACCEPTED },
            select: { userId: true },
          },
        },
      });
      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      if (!match.participants.some((participant) => participant.userId === senderUserId)) {
        throw new ForbiddenException('Chỉ participant ACCEPTED của trận được gửi feedback');
      }
      if (match.status !== MatchState.COMPLETED || match.startTime > new Date()) {
        throw new ConflictException('Trận đấu chưa đủ điều kiện nhận feedback');
      }
      if (!match.participants.some((participant) => participant.userId === dto.recipientUserId)) {
        throw new BadRequestException('Người nhận không hợp lệ trong trận');
      }
      try {
        const feedback = await db.feedback.create({
          data: { matchId, senderUserId, recipientUserId: dto.recipientUserId, rating: dto.rating, comment: dto.comment ?? null },
          select: { id: true, matchId: true, senderUserId: true, recipientUserId: true, rating: true, comment: true, createdAt: true },
        });
        return {
          id: feedback.id, matchId: feedback.matchId, senderUserId: feedback.senderUserId,
          recipientUserId: feedback.recipientUserId, rating: feedback.rating,
          comment: feedback.comment, createdAt: feedback.createdAt,
        };
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError) {
          const target = error.meta?.target;
          const keys = ['matchId', 'senderUserId', 'recipientUserId'];
          const duplicate = Array.isArray(target)
            ? target.length === keys.length && keys.every((key) => target.includes(key))
            : target === 'Feedback_matchId_senderUserId_recipientUserId_key';
          if (error.code === 'P2002' && duplicate && (!error.meta?.modelName || error.meta.modelName === 'Feedback')) {
            throw new ConflictException('Bạn đã gửi feedback cho người chơi này trong trận');
          }
          if (error.code === 'P2034') throw new ConflictException('Dữ liệu feedback đang có xung đột');
        }
        // Do not let the generic Match error mapper misclassify Feedback constraints.
        throw new InternalServerErrorException('Không thể lưu feedback');
      }
    });
  }

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

  private requireFutureStart(startTime: Date | undefined) {
    if (startTime && startTime <= new Date()) {
      throw new ConflictException('This match has already started');
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
    if ((dto.mode === 'SINGLES' && dto.neededPlayers !== 1) || (dto.mode === 'DOUBLES' && dto.neededPlayers !== 3)) {
      throw new BadRequestException('Capacity must match singles or doubles format');
    }
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
            description: dto.description,
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
    const geo = [query.latitude, query.longitude, query.distanceKm];
    if (geo.some((v) => v !== undefined) && geo.some((v) => v === undefined)) throw new BadRequestException('Latitude, longitude and distance are required together');
    let dateStart: Date | undefined;
    let dateEnd: Date | undefined;
    if (query.date) {
      dateStart = new Date(`${query.date}T00:00:00+07:00`);
      if (!Number.isFinite(dateStart.getTime()) || new Date(dateStart.getTime() + 7 * 3600000).toISOString().slice(0, 10) !== query.date) throw new BadRequestException('Invalid date');
      dateEnd = new Date(dateStart.getTime() + 86400000);
    }
    const matches = await this.prisma.match.findMany({
      where: {
        privacy: MatchPrivacy.OPEN,
        status: MatchState.OPEN,
        startTime: { gt: new Date(), ...(dateStart && { gte: dateStart }), ...(dateEnd && { lt: dateEnd }) },
        ...(query.skill !== undefined && { minSkillLevel: { lte: query.skill }, maxSkillLevel: { gte: query.skill } }),
        ...(query.mode && { mode: query.mode }),
        ...(query.purpose && { purpose: query.purpose }),
      },
      select: MATCH_PUBLIC_SELECT,
      orderBy: { createdAt: 'desc' },
    });
    return matches.map(toMatchResponse).filter((match) => {
      if (query.distanceKm === undefined) return true;
      const facility = match.booking?.court.facility;
      if (facility?.latitude == null || facility.longitude == null) return false;
      const rad = Math.PI / 180;
      const dLat = (facility.latitude - query.latitude!) * rad;
      const dLon = (facility.longitude - query.longitude!) * rad;
      const h = Math.sin(dLat / 2) ** 2 + Math.cos(query.latitude! * rad) * Math.cos(facility.latitude * rad) * Math.sin(dLon / 2) ** 2;
      return 12742 * Math.asin(Math.min(1, Math.sqrt(h))) <= query.distanceKm;
    });
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
    return this.withMatchLock(matchId, async (db) => {
      const match = await this.getMatchForParticipation(matchId, db);
      if (match.hostId === userId) {
        throw new BadRequestException('Host không thể rời trận đấu của mình');
      }
      this.requireNotCompleted(match.status);
      const participant = match.participants.find((entry) => entry.userId === userId);
      if (!participant || (
        participant.status !== ParticipantStatus.REQUESTED &&
        participant.status !== ParticipantStatus.INVITED &&
        participant.status !== ParticipantStatus.ACCEPTED
      )) {
        throw new NotFoundException('Bạn không có lời mời hoặc yêu cầu tham gia đang hoạt động');
      }
      await db.matchParticipant.update({
        where: { id: participant.id },
        data: { status: ParticipantStatus.CANCELLED },
      });
      await this.checkAndUpdateMatchFullState(matchId, db);
      // Membership has been removed; do not return PRIVATE detail after leaving.
      return { id: matchId, left: true };
    });
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

  async findMyMatches(userId: number) {
    const matches = await this.prisma.match.findMany({
      where: { privacy: MatchPrivacy.OPEN, OR: [{ hostId: userId }, { participants: { some: { userId } } }] },
      select: { ...MATCH_PUBLIC_SELECT, participants: { where: { userId }, select: { status: true } } },
      orderBy: { startTime: 'asc' },
    });
    const hostedIds = matches.filter((match) => match.hostId === userId).map((match) => match.id);
    const pending = hostedIds.length ? await this.prisma.matchParticipant.groupBy({
      by: ['matchId'], where: { matchId: { in: hostedIds }, status: ParticipantStatus.REQUESTED }, _count: { _all: true },
    }) : [];
    const counts = new Map(pending.map((entry) => [entry.matchId, entry._count._all]));
    return matches.map(({ participants, ...match }) => ({ ...toMatchResponse(match), myStatus: participants[0]?.status ?? null,
      ...(match.hostId === userId ? { pendingRequestCount: counts.get(match.id) ?? 0 } : {}),
    }));
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
    if (select === MATCH_INVITATION_SELECT) return { ...match, myStatus: membership ?? null };
    return { ...toMatchResponse(match), myStatus: membership ?? null };
  }

  private async getMatchForParticipation(id: number, db: Prisma.TransactionClient = this.prisma) {
    const match = await db.match.findUnique({
      where: { id },
      select: {
        id: true, hostId: true, status: true,
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
    return this.withMatchLock(matchId, (db) => this.updateMatchForHost(db, matchId, userId, dto));
  }

  private async updateMatchForHost(db: Prisma.TransactionClient, matchId: number, userId: number, dto: UpdateMatchDto) {
    const match = await db.match.findUnique({
      where: { id: matchId }, select: { id: true, hostId: true, status: true, bookingId: true, startTime: true, endTime: true },
    });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== userId) {
      throw new ForbiddenException('Chỉ có Host mới có quyền chỉnh sửa trận đấu');
    }

    this.requireNotCompleted(match.status);

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
      where: { id: matchId, hostId: match.hostId, status: { not: MatchState.COMPLETED } }, data, select: MATCH_MANAGER_SELECT,
    });
    return toMatchResponse(updated);
  }

  // 5. Hủy Match (Chỉ Host)
  async cancelMatch(matchId: number, userId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({ where: { id: matchId } });
      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      if (match.hostId !== userId) {
        throw new ForbiddenException('Chỉ có Host mới có quyền hủy trận đấu');
      }
      this.requireNotCompleted(match.status);

      const cancelled = await db.match.update({
        where: { id: matchId, status: { not: MatchState.COMPLETED } },
        data: { status: MatchState.CANCELLED },
        select: MATCH_MANAGER_SELECT,
      });
      return toMatchResponse(cancelled);
    });
  }

  // 6. Host mời thành viên vào trận
  async inviteUser(matchId: number, hostUserId: number, targetUserId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({
        where: { id: matchId },
        include: { participants: true },
      });
      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      if (match.hostId !== hostUserId) {
        throw new ForbiddenException('Chỉ có Host mới có quyền gửi lời mời');
      }
      this.requireNotCompleted(match.status);
      this.requireOpenForAcceptance(match.status);
      this.requireFutureStart(match.startTime);
      if (targetUserId === hostUserId) throw new ConflictException('Organizer cannot invite themselves');
      if (match.privacy === MatchPrivacy.OPEN) {
        const profile = (userId: number) => db.playerProfile.findFirst({
          where: { userId, locationSharingEnabled: true, user: { role: { name: 'PLAYER' } } },
          select: invitationProfileSelect,
        });
        const [host, target] = await Promise.all([profile(hostUserId), profile(targetUserId)]);
        if (!eligibleNearbyInvite(host, target, match.minSkillLevel, match.maxSkillLevel)) {
          throw new ForbiddenException('Player is not eligible for nearby invitations');
        }
      } else {
        const target = await db.user.findFirst({
          where: { id: targetUserId, role: { name: 'PLAYER' } }, select: { id: true },
        });
        if (!target) throw new NotFoundException('Player not found');
      }
      if (match.participants.filter((participant) => participant.status === ParticipantStatus.ACCEPTED).length >= match.maxPlayers) {
        throw new ConflictException('This match is full');
      }

      const existing = match.participants.find((p: any) => p.userId === targetUserId);
      if (existing) {
        if (existing.status === ParticipantStatus.INVITED) {
          throw new ConflictException('An invitation is already pending');
        }
        if (existing.status === ParticipantStatus.REQUESTED) {
          throw new ConflictException('Bạn đã gửi yêu cầu tham gia trận này');
        }
        if (existing.status === ParticipantStatus.ACCEPTED) {
          throw new BadRequestException('Người chơi này đã tham gia trận');
        }
        const invitation = await db.matchParticipant.update({
          where: { id: existing.id },
          data: { status: ParticipantStatus.INVITED },
          select: MATCH_PARTICIPANT_MUTATION_SELECT,
        });
        await db.matchNotification.create({ data: { userId: targetUserId, matchId, kind: 'INVITATION' } });
        return invitation;
      }

      const invitation = await db.matchParticipant.create({
        data: {
          matchId,
          userId: targetUserId,
          role: ParticipantRole.MEMBER,
          status: ParticipantStatus.INVITED,
        },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });
      await db.matchNotification.create({ data: { userId: targetUserId, matchId, kind: 'INVITATION' } });
      return invitation;
    });
  }

  // 7. Người chơi xin vào Open Match
  async requestToJoin(matchId: number, userId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({
        where: { id: matchId },
        include: {
          participants: { where: { status: ParticipantStatus.ACCEPTED } },
        },
      });

      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      this.requireNotCompleted(match.status);
      if (match.hostId === userId) throw new ConflictException('Organizer cannot request to join their own match');
      this.requireFutureStart(match.startTime);
      if (match.status !== MatchState.OPEN) {
        throw new BadRequestException('Trận đấu này hiện không mở để tham gia');
      }
      if (match.privacy === MatchPrivacy.PRIVATE) {
        throw new BadRequestException('Đây là trận đấu kín (Private), cần có lời mời từ Host');
      }
      if (match.participants.length >= match.maxPlayers) {
        throw new BadRequestException('Trận đấu đã đủ số lượng người chơi');
      }

      const existing = await db.matchParticipant.findUnique({
        where: { matchId_userId: { matchId, userId } },
      });

      if (existing) {
        if (existing.status === ParticipantStatus.REQUESTED) {
          throw new ConflictException('A join request is already pending');
        }
        if (existing.status === ParticipantStatus.ACCEPTED) {
          throw new BadRequestException('Bạn đã là thành viên của trận này');
        }
        if (existing.status === ParticipantStatus.INVITED) {
          throw new ConflictException('Respond to the existing invitation instead');
        }
        const request = await db.matchParticipant.update({
          where: { id: existing.id },
          data: { status: ParticipantStatus.REQUESTED },
          select: MATCH_PARTICIPANT_MUTATION_SELECT,
        });
        await db.matchNotification.create({ data: { userId: match.hostId, matchId, kind: 'JOIN_REQUEST' } });
        return request;
      }

      const request = await db.matchParticipant.create({
        data: {
          matchId,
          userId,
          role: ParticipantRole.MEMBER,
          status: ParticipantStatus.REQUESTED,
        },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });
      await db.matchNotification.create({ data: { userId: match.hostId, matchId, kind: 'JOIN_REQUEST' } });
      return request;
    });
  }

  // 8. Chấp nhận lời mời (Accept Invitation)
  async acceptInvitation(matchId: number, userId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const participant = await db.matchParticipant.findUnique({
        where: { matchId_userId: { matchId, userId } },
        include: { match: { include: { participants: { where: { status: ParticipantStatus.ACCEPTED } } } } },
      });

      if (!participant || participant.status !== ParticipantStatus.INVITED) {
        throw new BadRequestException('Không tìm thấy lời mời hợp lệ');
      }

      this.requireOpenForAcceptance(participant.match.status);
      this.requireFutureStart(participant.match.startTime);
      if (participant.match.participants.length >= participant.match.maxPlayers) {
        throw new BadRequestException('Trận đấu đã đầy người chơi');
      }

      const updated = await db.matchParticipant.update({
        where: { id: participant.id },
        data: { status: ParticipantStatus.ACCEPTED },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });

      await this.checkAndUpdateMatchFullState(matchId, db);
      return updated;
    });
  }

  // 9. Từ chối lời mời (Reject Invitation)
  async rejectInvitation(matchId: number, userId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const participant = await db.matchParticipant.findUnique({
        where: { matchId_userId: { matchId, userId } },
        include: { match: { select: { status: true } } },
      });

      if (!participant || participant.status !== ParticipantStatus.INVITED) {
        throw new BadRequestException('Không tìm thấy lời mời hợp lệ');
      }

      this.requireNotCompleted(participant.match.status);
      if (participant.match.status === MatchState.CANCELLED) throw new ConflictException('Trận đấu đã bị hủy');
      return db.matchParticipant.update({
        where: { id: participant.id },
        data: { status: ParticipantStatus.REJECTED },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });
    });
  }

  // 10. Host duyệt yêu cầu xin vào trận
  async hostApproveRequest(matchId: number, hostUserId: number, applicantUserId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({
        where: { id: matchId },
        include: { participants: { where: { status: ParticipantStatus.ACCEPTED } } },
      });

      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      if (match.hostId !== hostUserId) {
        throw new ForbiddenException('Chỉ Host mới có quyền duyệt yêu cầu');
      }
      this.requireOpenForAcceptance(match.status);
      this.requireFutureStart(match.startTime);
      if (match.participants.length >= match.maxPlayers) {
        throw new BadRequestException('Trận đấu đã đủ người chơi');
      }

      const participant = await db.matchParticipant.findUnique({
        where: { matchId_userId: { matchId, userId: applicantUserId } },
      });

      if (!participant || participant.status !== ParticipantStatus.REQUESTED) {
        throw new BadRequestException('Không tìm thấy yêu cầu tham gia hợp lệ của người này');
      }

      const updated = await db.matchParticipant.update({
        where: { id: participant.id },
        data: { status: ParticipantStatus.ACCEPTED },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });

      await this.checkAndUpdateMatchFullState(matchId, db);
      await db.matchNotification.create({ data: { userId: applicantUserId, matchId, kind: 'REQUEST_APPROVED' } });
      return updated;
    });
  }

  // 11. Host từ chối yêu cầu xin vào trận
  async hostRejectRequest(matchId: number, hostUserId: number, applicantUserId: number) {
    return this.withMatchLock(matchId, async (db) => {
      const match = await db.match.findUnique({ where: { id: matchId } });
      if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
      if (match.hostId !== hostUserId) {
        throw new ForbiddenException('Chỉ Host mới có quyền từ chối yêu cầu');
      }
      this.requireNotCompleted(match.status);

      const participant = await db.matchParticipant.findUnique({
        where: { matchId_userId: { matchId, userId: applicantUserId } },
      });

      if (!participant || participant.status !== ParticipantStatus.REQUESTED) {
        throw new BadRequestException('Không tìm thấy yêu cầu tham gia hợp lệ của người này');
      }

      const rejected = await db.matchParticipant.update({
        where: { id: participant.id },
        data: { status: ParticipantStatus.REJECTED },
        select: MATCH_PARTICIPANT_MUTATION_SELECT,
      });
      await db.matchNotification.create({ data: { userId: applicantUserId, matchId, kind: 'REQUEST_REJECTED' } });
      return rejected;
    });
  }

  private async checkAndUpdateMatchFullState(matchId: number, db: Prisma.TransactionClient) {
    const match = await db.match.findUnique({
      where: { id: matchId },
      include: {
        booking: true,
        participants: { where: { status: ParticipantStatus.ACCEPTED } },
      },
    });

    if (!match || (match.status !== MatchState.OPEN && match.status !== MatchState.FULL)) return;
    await db.match.updateMany({
      where: { id: matchId, status: { in: [MatchState.OPEN, MatchState.FULL] } },
      data: {
        status: match.participants.length >= match.maxPlayers ? MatchState.FULL : MatchState.OPEN,
        ...(match.booking && { feePerPlayer: match.booking.totalPrice / Math.max(1, match.participants.length) }),
      },
    });
  }
}
