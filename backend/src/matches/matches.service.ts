import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMatchDto } from './dto/create-match.dto';
import { UpdateMatchDto } from './dto/update-match.dto';
import { BookingStatus, MatchPrivacy, MatchState, ParticipantRole, ParticipantStatus, Prisma } from '@prisma/client';
import { CreateOpenMatchDto, QueryOpenMatchDto } from './dto/open-match.dto';

@Injectable()
export class MatchesService {
  constructor(private readonly prisma: PrismaService) {}

  async createFromBooking(hostUserId: number, bookingId: number, dto: CreateOpenMatchDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { court: { include: { facility: true } }, match: true },
    });
    if (!booking) {
      throw new NotFoundException(`Không tìm thấy đơn đặt sân ID ${bookingId}`);
    }
    if (booking.userId !== hostUserId) {
      throw new ForbiddenException('Chỉ người đã đặt sân mới có thể mở trận đấu cho đơn này');
    }
    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new BadRequestException('Chỉ có thể mở trận đấu cho đơn đặt sân đã xác nhận');
    }
    if (booking.match) {
      throw new BadRequestException('Đơn đặt sân này đã có trận đấu');
    }
    if (dto.minSkillLevel > dto.maxSkillLevel) {
      throw new BadRequestException('minSkillLevel không được lớn hơn maxSkillLevel');
    }

    const maxPlayers = dto.neededPlayers + 1;
    return this.prisma.match.create({
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
      include: { booking: { include: { court: { include: { facility: true } } } }, participants: true },
    });
  }

  findAll(query: QueryOpenMatchDto) {
    return this.prisma.match.findMany({
      where: {
        privacy: MatchPrivacy.OPEN,
        status: MatchState.OPEN,
        ...(query.mode && { mode: query.mode }),
        ...(query.purpose && { purpose: query.purpose }),
      },
      include: {
        booking: { include: { court: { include: { facility: true } } } },
        participants: { include: { user: { select: { id: true, fullName: true, email: true } } } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  findOneOrThrow(id: number) {
    return this.findOne(id);
  }

  async respondToRequest(hostUserId: number, matchId: number, participantId: number, accept: boolean) {
    const match = await this.findOne(matchId);
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
    const match = await this.findOne(matchId);
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
    return this.findOne(matchId);
  }

  // 1. Tạo Match mới (Người tạo tự động thành HOST và status ACCEPTED)
  async createMatch(userId: number, dto: CreateMatchDto) {
    const start = new Date(dto.startTime);
    const end = new Date(dto.endTime);

    if (start >= end) {
      throw new BadRequestException('Thời gian bắt đầu phải trước thời gian kết thúc');
    }

    return this.prisma.$transaction(async (tx: any) => {
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
        include: {
          host: { select: { id: true, email: true, fullName: true } },
          participants: {
            include: {
              user: { select: { id: true, email: true, fullName: true } },
            },
          },
        },
      });

      return match;
    });
  }

  // 2. Lấy danh sách Open Matches để tìm kèo
  async findOpenMatches() {
    return this.prisma.match.findMany({
      where: {
        privacy: MatchPrivacy.OPEN,
        status: { in: [MatchState.OPEN, MatchState.FULL] },
      },
      include: {
        host: { select: { id: true, email: true, fullName: true } },
        participants: {
          where: { status: ParticipantStatus.ACCEPTED },
          include: {
            user: { select: { id: true, email: true, fullName: true } },
          },
        },
      },
      orderBy: { startTime: 'asc' },
    });
  }

  // 3. Xem chi tiết Match
  async findOne(id: number) {
    const match = await this.prisma.match.findUnique({
      where: { id },
      include: {
        host: { select: { id: true, email: true, fullName: true } },
        booking: {
          include: {
            court: {
              include: { facility: true },
            },
          },
        },
        participants: {
          include: {
            user: { select: { id: true, email: true, fullName: true } },
          },
        },
      },
    });

    if (!match) {
      throw new NotFoundException('Không tìm thấy trận đấu');
    }

    return match;
  }

  // 4. Cập nhật thông tin Match (Chỉ Host)
  async updateMatch(matchId: number, userId: number, dto: UpdateMatchDto) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== userId) {
      throw new ForbiddenException('Chỉ có Host mới có quyền chỉnh sửa trận đấu');
    }

    const data: any = { ...dto };
    if (dto.startTime) data.startTime = new Date(dto.startTime);
    if (dto.endTime) data.endTime = new Date(dto.endTime);

    return this.prisma.match.update({
      where: { id: matchId },
      data,
    });
  }

  // 5. Hủy Match (Chỉ Host)
  async cancelMatch(matchId: number, userId: number) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('Không tìm thấy trận đấu');
    if (match.hostId !== userId) {
      throw new ForbiddenException('Chỉ có Host mới có quyền hủy trận đấu');
    }

    return this.prisma.match.update({
      where: { id: matchId },
      data: { status: MatchState.CANCELLED },
    });
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
      });
    }

    return this.prisma.matchParticipant.create({
      data: {
        matchId,
        userId: targetUserId,
        role: ParticipantRole.MEMBER,
        status: ParticipantStatus.INVITED,
      },
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
      });
    }

    return this.prisma.matchParticipant.create({
      data: {
        matchId,
        userId,
        role: ParticipantRole.MEMBER,
        status: ParticipantStatus.REQUESTED,
      },
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

    if (participant.match.participants.length >= participant.match.maxPlayers) {
      throw new BadRequestException('Trận đấu đã đầy người chơi');
    }

    const updated = await this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.ACCEPTED },
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
