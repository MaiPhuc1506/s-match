import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus, OpenMatchStatus, ParticipantStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOpenMatchDto, QueryOpenMatchDto } from './dto/open-match.dto';

const bookingWithFacilityInclude = {
  court: { include: { facility: true } },
} as const;

const openMatchDetailInclude = {
  booking: { include: bookingWithFacilityInclude },
  participants: { include: { user: { select: { id: true, fullName: true, email: true } } } },
} as const;

@Injectable()
export class MatchesService {
  constructor(private readonly prisma: PrismaService) {}

  // Chủ booking ("host") mở đơn đặt sân đã CONFIRMED thành một Open Match
  async createFromBooking(hostUserId: number, bookingId: number, dto: CreateOpenMatchDto) {
    const booking = await this.prisma.booking.findUnique({
      where: { id: bookingId },
      include: { openMatch: true },
    });
    if (!booking) {
      throw new NotFoundException(`Không tìm thấy đơn đặt sân ID ${bookingId}`);
    }
    if (booking.userId !== hostUserId) {
      throw new ForbiddenException('Chỉ người đã đặt sân mới có thể mở Open Match cho đơn này');
    }
    if (booking.status !== BookingStatus.CONFIRMED) {
      throw new BadRequestException('Chỉ có thể mở Open Match cho đơn đặt sân đã được xác nhận');
    }
    if (booking.openMatch) {
      throw new BadRequestException('Đơn đặt sân này đã được mở thành Open Match trước đó');
    }
    if (dto.minSkillLevel > dto.maxSkillLevel) {
      throw new BadRequestException('minSkillLevel không được lớn hơn maxSkillLevel');
    }

    const totalPlayers = dto.neededPlayers + 1; // + host
    const estimatedCostPerPerson = booking.totalPrice / totalPlayers;

    return this.prisma.openMatch.create({
      data: {
        bookingId: booking.id,
        mode: dto.mode,
        purpose: dto.purpose,
        neededPlayers: dto.neededPlayers,
        minSkillLevel: dto.minSkillLevel,
        maxSkillLevel: dto.maxSkillLevel,
        estimatedCostPerPerson,
        status: OpenMatchStatus.OPEN,
      },
      include: openMatchDetailInclude,
    });
  }

  // Public — Player duyệt danh sách Open Match đang mở
  findAll(query: QueryOpenMatchDto) {
    return this.prisma.openMatch.findMany({
      where: {
        status: OpenMatchStatus.OPEN,
        ...(query.mode && { mode: query.mode }),
        ...(query.purpose && { purpose: query.purpose }),
      },
      include: openMatchDetailInclude,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOneOrThrow(id: number) {
    const openMatch = await this.prisma.openMatch.findUnique({
      where: { id },
      include: openMatchDetailInclude,
    });
    if (!openMatch) {
      throw new NotFoundException(`Không tìm thấy Open Match ID ${id}`);
    }
    return openMatch;
  }

  // Player gửi yêu cầu tham gia (PENDING, chờ host duyệt)
  async requestToJoin(userId: number, openMatchId: number) {
    const openMatch = await this.findOneOrThrow(openMatchId);
    if (openMatch.status !== OpenMatchStatus.OPEN) {
      throw new BadRequestException('Trận đấu này hiện không mở để tham gia');
    }
    if (openMatch.booking.userId === userId) {
      throw new BadRequestException('Bạn là host của trận đấu này');
    }

    const existing = openMatch.participants.find((p) => p.userId === userId);
    if (existing && existing.status !== ParticipantStatus.LEFT) {
      throw new BadRequestException('Bạn đã gửi yêu cầu tham gia trận đấu này rồi');
    }

    return this.prisma.matchParticipant.upsert({
      where: { openMatchId_userId: { openMatchId, userId } },
      update: { status: ParticipantStatus.PENDING },
      create: { openMatchId, userId, status: ParticipantStatus.PENDING },
    });
  }

  // Host duyệt (accept) hoặc từ chối (reject) một yêu cầu tham gia
  async respondToRequest(
    hostUserId: number,
    openMatchId: number,
    participantId: number,
    accept: boolean,
  ) {
    const openMatch = await this.findOneOrThrow(openMatchId);
    if (openMatch.booking.userId !== hostUserId) {
      throw new ForbiddenException('Chỉ host mới có quyền duyệt yêu cầu tham gia');
    }

    const participant = openMatch.participants.find((p) => p.id === participantId);
    if (!participant) {
      throw new NotFoundException(`Không tìm thấy yêu cầu tham gia ID ${participantId}`);
    }
    if (participant.status !== ParticipantStatus.PENDING) {
      throw new BadRequestException('Yêu cầu này đã được xử lý trước đó');
    }

    await this.prisma.matchParticipant.update({
      where: { id: participantId },
      data: { status: accept ? ParticipantStatus.ACCEPTED : ParticipantStatus.REJECTED },
    });

    return this.recomputeMatchState(openMatchId);
  }

  // Player tự rời khỏi trận (hoặc rút yêu cầu đang PENDING)
  async leave(userId: number, openMatchId: number) {
    const openMatch = await this.findOneOrThrow(openMatchId);
    const participant = openMatch.participants.find(
      (p) => p.userId === userId && p.status !== ParticipantStatus.LEFT,
    );
    if (!participant) {
      throw new NotFoundException('Bạn không nằm trong trận đấu này');
    }

    await this.prisma.matchParticipant.update({
      where: { id: participant.id },
      data: { status: ParticipantStatus.LEFT },
    });

    return this.recomputeMatchState(openMatchId);
  }

  // Tính lại số người đã ACCEPTED, trạng thái OPEN/FULL, và chi phí chia đều mỗi người
  private async recomputeMatchState(openMatchId: number) {
    const openMatch = await this.findOneOrThrow(openMatchId);
    const acceptedCount = openMatch.participants.filter(
      (p) => p.status === ParticipantStatus.ACCEPTED,
    ).length;
    const totalPlayers = acceptedCount + 1; // + host
    const targetTotalPlayers = openMatch.neededPlayers + 1;

    const status =
      openMatch.status === OpenMatchStatus.CANCELLED
        ? openMatch.status
        : totalPlayers >= targetTotalPlayers
          ? OpenMatchStatus.FULL
          : OpenMatchStatus.OPEN;

    return this.prisma.openMatch.update({
      where: { id: openMatchId },
      data: {
        status,
        estimatedCostPerPerson: openMatch.booking.totalPrice / totalPlayers,
      },
      include: openMatchDetailInclude,
    });
  }
}
