import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { replayPlayerSkill } from './skill-progression.persistence';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { assessmentScore, effectiveSkillLevel } from './skill-assessment';

@Injectable()
export class PlayersService {
  constructor(private readonly prisma: PrismaService) {}

  // Six ordered self-reported answers, one per axis; choice 0–4 maps to 1–5.
  // Insert only: an existing skill record (including legacy scores) is never overwritten.
  async submitInitialSkill(userId: number, answers: number[]) {
    if (!Array.isArray(answers) || answers.length !== 6 || answers.some((a) => !Number.isInteger(a) || a < 0 || a > 4)) {
      throw new BadRequestException('Exactly six valid answers are required.');
    }
    const [smash, defense, netPlay, stamina, footwork, serve] = answers.map((answer) => answer + 1);
    try {
      return await this.prisma.$transaction(async tx => {
        await tx.$queryRaw`SELECT pg_advisory_xact_lock(736123, ${userId}::integer)::text AS locked`;
        const profile = await tx.playerProfile.upsert({ where: { userId }, create: { userId }, update: {}, select: { id: true } });
        await tx.skill.create({ data: { playerProfileId: profile.id, smash, defense, netPlay, stamina, footwork, serve, initialSource: 'INITIAL_ESTIMATE', initialScores: { smash, defense, netPlay, stamina, footwork, serve } } });
        await replayPlayerSkill(tx, userId);
        const skill = await tx.skill.findUniqueOrThrow({ where: { playerProfileId: profile.id } });
        return { kind: 'INITIAL_ESTIMATE', skill, overallSkillScore: assessmentScore(skill) };
      });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('A skill assessment already exists.');
      throw error;
    }
  }

  async getMyProfile(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        fullName: true,
        phone: true,
        role: { select: { name: true } },
        playerProfile: { include: { skill: true } },
      },
    });

    if (!user) {
      throw new NotFoundException('Không tìm thấy thông tin người dùng');
    }

    if (!user.playerProfile) {
      const newProfile = await this.prisma.playerProfile.create({
        data: { userId },
      });
      return { ...user, playerProfile: { ...newProfile, skill: null, overallSkillScore: null } };
    }

    const overallSkillScore = assessmentScore(user.playerProfile.skill);
    return { ...user, playerProfile: {
      ...user.playerProfile, overallSkillScore,
      skillLevel: effectiveSkillLevel(overallSkillScore, user.playerProfile.skillLevel),
    } };
  }

  async updateMyProfile(userId: number, dto: UpdateProfileDto) {
    const { fullName, phone, phoneNumber, completeGoogleOnboarding, ...profileData } = dto;
    const targetPhone = phone ?? phoneNumber;

    const updatedUser = await this.prisma.$transaction(async (db) => {
      const updated = await db.user.update({
      where: { id: userId },
      data: {
        fullName,
        phone: targetPhone,
        playerProfile: {
          upsert: {
            create: profileData,
            update: profileData,
          },
        },
      },
      select: {
        id: true,
        email: true,
        fullName: true,
        phone: true,
        playerProfile: true,
      },
    });

      if (fullName?.trim() && (completeGoogleOnboarding === true || profileData.playingArea?.trim())) {
        await db.googleIdentity.updateMany({ where: { userId, onboardingPending: true }, data: { onboardingPending: false } });
      }
      return updated;
    });
    return updatedUser;
  }
}
