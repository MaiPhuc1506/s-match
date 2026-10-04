import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { MatchesService } from './matches.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookingStatus, OpenMatchStatus, ParticipantStatus } from '@prisma/client';

describe('MatchesService', () => {
  let service: MatchesService;
  let prisma: any;

  const mockBooking = {
    id: 1,
    userId: 5, // host
    status: BookingStatus.CONFIRMED,
    totalPrice: 240000,
    openMatch: null,
  };

  const createDto = {
    mode: 'DOUBLES' as const,
    purpose: 'CASUAL' as const,
    neededPlayers: 2,
    minSkillLevel: 2,
    maxSkillLevel: 4,
  };

  beforeEach(async () => {
    prisma = {
      booking: { findUnique: jest.fn() },
      openMatch: { create: jest.fn(), findMany: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
      matchParticipant: { upsert: jest.fn(), update: jest.fn() },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [MatchesService, { provide: PrismaService, useValue: prisma }],
    }).compile();

    service = module.get<MatchesService>(MatchesService);
  });

  describe('createFromBooking', () => {
    it('should throw NotFoundException if booking does not exist', async () => {
      prisma.booking.findUnique.mockResolvedValue(null);
      await expect(service.createFromBooking(5, 999, createDto)).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException if requester is not the booking owner', async () => {
      prisma.booking.findUnique.mockResolvedValue(mockBooking);
      await expect(service.createFromBooking(999, 1, createDto)).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException if booking is not CONFIRMED', async () => {
      prisma.booking.findUnique.mockResolvedValue({ ...mockBooking, status: BookingStatus.PENDING });
      await expect(service.createFromBooking(5, 1, createDto)).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if booking already has an OpenMatch', async () => {
      prisma.booking.findUnique.mockResolvedValue({ ...mockBooking, openMatch: { id: 1 } });
      await expect(service.createFromBooking(5, 1, createDto)).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if minSkillLevel > maxSkillLevel', async () => {
      prisma.booking.findUnique.mockResolvedValue(mockBooking);
      await expect(
        service.createFromBooking(5, 1, { ...createDto, minSkillLevel: 5, maxSkillLevel: 1 }),
      ).rejects.toThrow(BadRequestException);
    });

    it('should create the OpenMatch with correct estimated cost per person', async () => {
      prisma.booking.findUnique.mockResolvedValue(mockBooking);
      prisma.openMatch.create.mockResolvedValue({ id: 1, estimatedCostPerPerson: 80000 });

      await service.createFromBooking(5, 1, createDto);

      expect(prisma.openMatch.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ estimatedCostPerPerson: 240000 / 3 }),
        }),
      );
    });
  });

  describe('requestToJoin', () => {
    const openMatch = {
      id: 1,
      status: OpenMatchStatus.OPEN,
      booking: { userId: 5, totalPrice: 240000 },
      participants: [],
    };

    it('should throw BadRequestException if match is not OPEN', async () => {
      prisma.openMatch.findUnique.mockResolvedValue({ ...openMatch, status: OpenMatchStatus.FULL });
      await expect(service.requestToJoin(10, 1)).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException if requester is the host', async () => {
      prisma.openMatch.findUnique.mockResolvedValue(openMatch);
      await expect(service.requestToJoin(5, 1)).rejects.toThrow(BadRequestException);
    });

    it('should upsert a PENDING participant request', async () => {
      prisma.openMatch.findUnique.mockResolvedValue(openMatch);
      prisma.matchParticipant.upsert.mockResolvedValue({ id: 1, status: ParticipantStatus.PENDING });

      await service.requestToJoin(10, 1);
      expect(prisma.matchParticipant.upsert).toHaveBeenCalled();
    });
  });

  describe('respondToRequest', () => {
    const openMatch = {
      id: 1,
      neededPlayers: 2,
      status: OpenMatchStatus.OPEN,
      booking: { userId: 5, totalPrice: 240000 },
      participants: [{ id: 100, userId: 10, status: ParticipantStatus.PENDING }],
    };

    it('should throw ForbiddenException if requester is not the host', async () => {
      prisma.openMatch.findUnique.mockResolvedValue(openMatch);
      await expect(service.respondToRequest(999, 1, 100, true)).rejects.toThrow(ForbiddenException);
    });

    it('should throw NotFoundException if participant does not exist', async () => {
      prisma.openMatch.findUnique.mockResolvedValue(openMatch);
      await expect(service.respondToRequest(5, 1, 9999, true)).rejects.toThrow(NotFoundException);
    });

    it('should accept the participant and recompute match state', async () => {
      prisma.openMatch.findUnique
        .mockResolvedValueOnce(openMatch)
        .mockResolvedValueOnce({
          ...openMatch,
          participants: [{ id: 100, userId: 10, status: ParticipantStatus.ACCEPTED }],
        });
      prisma.matchParticipant.update.mockResolvedValue({});
      prisma.openMatch.update.mockResolvedValue({ status: OpenMatchStatus.OPEN });

      await service.respondToRequest(5, 1, 100, true);

      expect(prisma.matchParticipant.update).toHaveBeenCalledWith(
        expect.objectContaining({ data: { status: ParticipantStatus.ACCEPTED } }),
      );
    });
  });
});
