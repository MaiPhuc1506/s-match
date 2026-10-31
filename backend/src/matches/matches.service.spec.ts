import { BadRequestException, ConflictException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { BookingStatus, MatchPrivacy, MatchState, ParticipantStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { MatchesService } from './matches.service';

describe('MatchesService', () => {
  let service: MatchesService;
  let prisma: any;

  const booking = {
    id: 1, userId: 5, status: BookingStatus.CONFIRMED, totalPrice: 240000,
    startTime: new Date('2026-10-20T18:00:00Z'),
    endTime: new Date('2026-10-20T20:00:00Z'),
    court: { facility: { name: 'Sunrise Badminton Club' } }, match: null,
  };
  const createDto = {
    mode: 'DOUBLES' as const, purpose: 'CASUAL' as const,
    neededPlayers: 2, minSkillLevel: 2, maxSkillLevel: 4,
  };

  beforeEach(() => {
    prisma = {
      $queryRaw: jest.fn(async () => []),
      booking: { findUnique: jest.fn() },
      match: { create: jest.fn(), findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn(), updateMany: jest.fn() },
      matchParticipant: { findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
    };
    prisma.$transaction = jest.fn(async (callback) => callback(prisma));
    service = new MatchesService(prisma as PrismaService);
  });

  it('rejects a missing or invalid booking', async () => {
    prisma.booking.findUnique.mockResolvedValue(null);
    await expect(service.createFromBooking(5, 1, createDto)).rejects.toThrow(NotFoundException);
    prisma.booking.findUnique.mockResolvedValue(booking);
    await expect(service.createFromBooking(6, 1, createDto)).rejects.toThrow(ForbiddenException);
    prisma.booking.findUnique.mockResolvedValue({ ...booking, status: BookingStatus.PENDING });
    await expect(service.createFromBooking(5, 1, createDto)).rejects.toThrow(ConflictException);
    prisma.booking.findUnique.mockResolvedValue({ ...booking, match: { id: 9 } });
    await expect(service.createFromBooking(5, 1, createDto)).rejects.toThrow(ConflictException);
    prisma.booking.findUnique.mockResolvedValue(booking);
    await expect(service.createFromBooking(5, 1, { ...createDto, minSkillLevel: 5, maxSkillLevel: 1 })).rejects.toThrow(BadRequestException);
  });

  it('creates a booking-based Match with a host and shared fee', async () => {
    prisma.booking.findUnique.mockResolvedValue(booking);
    prisma.match.create.mockResolvedValue({ id: 7 });
    await service.createFromBooking(5, 1, createDto);
    expect(prisma.match.create).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        bookingId: 1, privacy: MatchPrivacy.OPEN, maxPlayers: 3,
        feePerPlayer: 80000, mode: 'DOUBLES', purpose: 'CASUAL',
        minSkillLevel: 2, maxSkillLevel: 4,
        participants: { create: { userId: 5, role: 'HOST', status: ParticipantStatus.ACCEPTED } },
      }),
    }));
  });

  it('filters public open matches', async () => {
    prisma.match.findMany.mockResolvedValue([]);
    await service.findAll({ mode: 'DOUBLES', purpose: 'CASUAL' });
    expect(prisma.match.findMany).toHaveBeenCalledWith(expect.objectContaining({
      where: { privacy: MatchPrivacy.OPEN, status: MatchState.OPEN, mode: 'DOUBLES', purpose: 'CASUAL' },
    }));
  });

  it('rejects a join request when the match is no longer open', async () => {
    prisma.match.findUnique.mockResolvedValue({
      id: 1, status: MatchState.CANCELLED, privacy: MatchPrivacy.OPEN,
      maxPlayers: 4, participants: [],
    });
    await expect(service.requestToJoin(1, 10)).rejects.toThrow(BadRequestException);
    expect(prisma.matchParticipant.create).not.toHaveBeenCalled();
  });

  it('requires the host and a pending participant to respond', async () => {
    const participant = { id: 100, userId: 10, status: ParticipantStatus.REQUESTED };
    prisma.match.findUnique.mockResolvedValue({ id: 1, hostId: 5, participants: [participant] });
    await expect(service.respondToRequest(6, 1, 100, true)).rejects.toThrow(ForbiddenException);
    await expect(service.respondToRequest(5, 1, 999, true)).rejects.toThrow(NotFoundException);
    const approve = jest.spyOn(service, 'hostApproveRequest').mockResolvedValue({ id: 100 } as any);
    await service.respondToRequest(5, 1, 100, true);
    expect(approve).toHaveBeenCalledWith(1, 5, 10);
    prisma.match.findUnique.mockResolvedValue({ id: 1, hostId: 5, participants: [{ ...participant, status: ParticipantStatus.ACCEPTED }] });
    await expect(service.respondToRequest(5, 1, 100, true)).rejects.toThrow(BadRequestException);
  });

  it('cancels participation and reopens a full match', async () => {
    const match = {
      id: 1, hostId: 5, status: MatchState.FULL, maxPlayers: 2,
      booking: { totalPrice: 240000 },
      participants: [
        { id: 1, userId: 5, status: ParticipantStatus.ACCEPTED },
        { id: 2, userId: 10, status: ParticipantStatus.ACCEPTED },
      ],
    };
    prisma.match.findUnique.mockResolvedValue(match);
    await expect(service.leave(5, 1)).rejects.toThrow(BadRequestException);
    await expect(service.leave(99, 1)).rejects.toThrow(NotFoundException);
    prisma.match.findUnique
      .mockResolvedValueOnce(match)
      .mockResolvedValueOnce({ ...match, participants: [match.participants[0]] })
      .mockResolvedValueOnce({ ...match, status: MatchState.OPEN });
    await service.leave(10, 1);
    expect(prisma.matchParticipant.update).toHaveBeenCalledWith({
      where: { id: 2 }, data: { status: ParticipantStatus.CANCELLED },
    });
    expect(prisma.match.updateMany).toHaveBeenCalledWith({
      where: { id: 1, status: { in: [MatchState.OPEN, MatchState.FULL] } }, data: { status: MatchState.OPEN, feePerPlayer: 240000 },
    });
  });
});
