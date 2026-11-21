import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BookingStatus } from '@prisma/client';
import { Role } from '../auth/roles.enum';
import { FacilitiesService } from '../facilities/facilities.service';
import { TimeSlotsService } from '../facilities/time-slots.service';
import { BookingsService } from '../bookings/bookings.service';
import { vietnamDay, vietnamTime } from '../bookings/booking-time';
import { MatchmakingService } from '../matchmaking.service';
import { CandidatesService } from '../candidates/candidates.service';
import { AvailabilityService } from '../availability-preference/availability.service';
import { RevenueAnalyticsService } from '../analytics/revenue-analytics.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { PrismaService } from '../prisma/prisma.service';
import { LlmToolDefinition } from './interfaces/llm-provider.interface';

export interface AiCallerContext {
  userId: number;
  role: Role;
  nearby?: { latitude: number; longitude: number; radiusKm: number };
}

export const ALLOWED_TOOL_NAMES = [
  'search_available_courts',
  'get_my_bookings',
  'recommend_players',
  'get_owner_analytics',
] as const;

export type AllowedToolName = (typeof ALLOWED_TOOL_NAMES)[number];

const FORBIDDEN_INPUT_KEYS = new Set([
  'sql',
  'query',
  'rawSql',
  'url',
  'endpoint',
  'callbackUrl',
  'userId',
  'ownerId',
  'role',
  'token',
  'accessToken',
]);

const SQL_OR_URL_INJECTION_REGEX =
  /(https?:\/\/|ftp:\/\/|file:\/\/|;\s*(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER|CREATE)\b|\bUNION\s+SELECT\b|--\s)/i;

@Injectable()
export class AiToolsService {
  constructor(
    private readonly facilitiesService: FacilitiesService,
    private readonly timeSlotsService: TimeSlotsService,
    private readonly bookingsService: BookingsService,
    private readonly matchmakingService: MatchmakingService,
    private readonly candidatesService: CandidatesService,
    private readonly availabilityService: AvailabilityService,
    private readonly revenueAnalyticsService: RevenueAnalyticsService,
    private readonly analyticsService: AnalyticsService,
    private readonly prisma: PrismaService,
  ) {}

  getToolDefinitions(): LlmToolDefinition[] {
    return [
      {
        name: 'search_available_courts',
        description:
          'Search public badminton facilities and available court time slots in Da Nang (Asia/Ho_Chi_Minh). Supports filtering by date, time window, max budget (VND), court type, and district/keyword.',
        parameters: {
          type: 'object',
          properties: {
            facilityId: {
              type: 'integer',
              description: 'Optional facility ID to check a specific facility.',
            },
            districtOrKeyword: {
              type: 'string',
              description: 'Optional facility name or district filter (e.g. "Hai Chau", "Son Tra").',
            },
            date: {
              type: 'string',
              description: 'Optional date in YYYY-MM-DD (Asia/Ho_Chi_Minh).',
            },
            startTimeFrom: {
              type: 'string',
              description: 'Optional earliest start time in HH:mm (24h format, Asia/Ho_Chi_Minh).',
            },
            endTimeTo: {
              type: 'string',
              description: 'Optional latest end time in HH:mm (24h format, Asia/Ho_Chi_Minh).',
            },
            maxPriceVnd: {
              type: 'number',
              description: 'Optional maximum price budget in VND (per slot or hourly rate).',
            },
            courtType: {
              type: 'string',
              enum: ['INDOOR', 'OUTDOOR'],
              description: 'Optional court type filter: INDOOR or OUTDOOR.',
            },
          },
        },
      },
      {
        name: 'get_my_bookings',
        description:
          'Get the authenticated user own bookings only (bound strictly to verified JWT user ID).',
        parameters: {
          type: 'object',
          properties: {
            status: {
              type: 'string',
              enum: ['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'],
              description: 'Optional booking status filter.',
            },
            upcomingOnly: {
              type: 'boolean',
              description: 'If true, only return bookings starting in the future.',
            },
            limit: {
              type: 'integer',
              description: 'Maximum number of bookings to return (1 to 20).',
            },
          },
        },
      },
      {
        name: 'recommend_players',
        description:
          'Get top compatible badminton player recommendations using the official 5-factor matchmaking service (Skill, Distance, Time Overlap, Reliability, Playing Style). Never exposes private GPS coordinates.',
        parameters: {
          type: 'object',
          properties: {
            maxDistanceKm: {
              type: 'number',
              description: 'Search radius in kilometers (0.5 to 50, default 10).',
            },
            minSkillLevel: {
              type: 'integer',
              description: 'Minimum preferred skill level (1 to 5).',
            },
            maxSkillLevel: {
              type: 'integer',
              description: 'Maximum preferred skill level (1 to 5).',
            },
            playingStyles: {
              type: 'array',
              items: { type: 'string' },
              description: 'Optional preferred playing styles: Attack, Defense, Balanced.',
            },
            limit: {
              type: 'integer',
              description: 'Max recommendations to return (1 to 10, default 5).',
            },
          },
        },
      },
      {
        name: 'get_owner_analytics',
        description:
          'Get Court Owner booking statistics, gross booked revenue, occupancy rate, and court utilization for owned facilities only. Restricted to COURT_OWNER role.',
        parameters: {
          type: 'object',
          properties: {
            facilityId: {
              type: 'integer',
              description: 'Optional owned facility ID. If omitted, aggregates across all facilities owned by the caller.',
            },
            from: {
              type: 'string',
              description: 'Optional start date YYYY-MM-DD in Asia/Ho_Chi_Minh.',
            },
            to: {
              type: 'string',
              description: 'Optional end date YYYY-MM-DD in Asia/Ho_Chi_Minh.',
            },
          },
        },
      },
    ];
  }

  async executeTool(
    toolName: string,
    rawArgs: unknown,
    caller: AiCallerContext,
  ): Promise<Record<string, unknown>> {
    if (!ALLOWED_TOOL_NAMES.includes(toolName as AllowedToolName)) {
      throw new BadRequestException(`Tool "${toolName}" is not in the read-only allowlist.`);
    }

    const args = this.validateAndSanitizeArgs(rawArgs);

    switch (toolName as AllowedToolName) {
      case 'search_available_courts':
        return this.searchAvailableCourts(args, caller.nearby);
      case 'get_my_bookings':
        return this.getMyBookings(caller, args);
      case 'recommend_players':
        return this.recommendPlayers(caller, args);
      case 'get_owner_analytics':
        return this.getOwnerAnalytics(caller, args);
    }
  }

  private validateAndSanitizeArgs(rawArgs: unknown): Record<string, unknown> {
    if (rawArgs === undefined || rawArgs === null) {
      return {};
    }
    if (typeof rawArgs !== 'object' || Array.isArray(rawArgs)) {
      throw new BadRequestException('Tool arguments must be a JSON object.');
    }

    const record = rawArgs as Record<string, unknown>;
    for (const [key, val] of Object.entries(record)) {
      if (FORBIDDEN_INPUT_KEYS.has(key)) {
        throw new BadRequestException(`Forbidden argument key: ${key}`);
      }
      if (typeof val === 'string' && SQL_OR_URL_INJECTION_REGEX.test(val)) {
        throw new BadRequestException(`Invalid characters or URL/SQL pattern in argument "${key}".`);
      }
    }
    return record;
  }

  private assertValidTimeFormat(time: unknown, fieldName: string): string | undefined {
    if (time === undefined || time === null || time === '') return undefined;
    if (typeof time !== 'string' || !/^([01]\d|2[0-4]):([0-5]\d)$/.test(time)) {
      throw new BadRequestException(`${fieldName} must be in HH:mm format (00:00 to 24:00).`);
    }
    const [h, m] = time.split(':').map(Number);
    if (h === 24 && m > 0) {
      throw new BadRequestException(`${fieldName} cannot exceed 24:00.`);
    }
    return time;
  }

  private assertValidDate(date: unknown, fieldName: string): string | undefined {
    if (date === undefined || date === null || date === '') return undefined;
    if (typeof date !== 'string') {
      throw new BadRequestException(`${fieldName} must be a YYYY-MM-DD string.`);
    }
    // Reuses vietnamDay which strictly validates YYYY-MM-DD and calendar validity in Asia/Ho_Chi_Minh
    vietnamDay(date);
    return date;
  }

  private async searchAvailableCourts(args: Record<string, unknown>, nearby?: AiCallerContext['nearby']): Promise<Record<string, unknown>> {
    const facilityId =
      args.facilityId !== undefined && args.facilityId !== null ? Number(args.facilityId) : undefined;
    if (facilityId !== undefined && (!Number.isInteger(facilityId) || facilityId < 1)) {
      throw new BadRequestException('facilityId must be a positive integer.');
    }

    const date = this.assertValidDate(args.date, 'date');
    const startTimeFrom = this.assertValidTimeFormat(args.startTimeFrom, 'startTimeFrom');
    const endTimeTo = this.assertValidTimeFormat(args.endTimeTo, 'endTimeTo');
    if (startTimeFrom && endTimeTo && startTimeFrom >= endTimeTo) {
      throw new BadRequestException('startTimeFrom must be earlier than endTimeTo.');
    }

    const maxPriceVnd =
      args.maxPriceVnd !== undefined && args.maxPriceVnd !== null ? Number(args.maxPriceVnd) : undefined;
    if (maxPriceVnd !== undefined && (!Number.isFinite(maxPriceVnd) || maxPriceVnd <= 0)) {
      throw new BadRequestException('maxPriceVnd must be a positive number.');
    }

    const courtType =
      typeof args.courtType === 'string' && args.courtType.trim() !== ''
        ? args.courtType.trim().toUpperCase()
        : undefined;
    if (courtType !== undefined && !['INDOOR', 'OUTDOOR'].includes(courtType)) {
      throw new BadRequestException('courtType must be INDOOR or OUTDOOR.');
    }

    const keyword =
      typeof args.districtOrKeyword === 'string' && args.districtOrKeyword.trim() !== ''
        ? args.districtOrKeyword.trim().toLowerCase()
        : undefined;

    const allFacilities = facilityId
      ? [await this.facilitiesService.getFacilityById(facilityId)]
      : await this.facilitiesService.getPublicFacilities();

    const distanceKm = (f: any): number | null => {
      const lat = f.latitude, lon = f.longitude;
      if (typeof lat !== 'number' || typeof lon !== 'number' || !Number.isFinite(lat) || !Number.isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) return null;
      if (!nearby) return null;
      const rad = Math.PI / 180, dLat = (lat - nearby.latitude) * rad, dLon = (lon - nearby.longitude) * rad;
      const a = Math.sin(dLat / 2) ** 2 + Math.cos(nearby.latitude * rad) * Math.cos(lat * rad) * Math.sin(dLon / 2) ** 2;
      return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
    };
    const filteredFacilities = allFacilities.filter((f: any) => {
      const distance = distanceKm(f);
      if (nearby && (distance === null || distance > nearby.radiusKm)) return false;
      if (!keyword) return true;
      const haystack = `${f.name ?? ''} ${f.address ?? ''} ${f.description ?? ''}`.toLowerCase();
      return haystack.includes(keyword);
    });
    if (nearby) filteredFacilities.sort((a: any, b: any) => distanceKm(a)! - distanceKm(b)!);

    const results: Array<Record<string, unknown>> = [];

    for (const facility of filteredFacilities.slice(0, 8)) {
      const activeCourts = ((facility as any).courts ?? []).filter((c: any) => {
        if (c.status !== 'ACTIVE') return false;
        if (courtType && String(c.courtType ?? 'INDOOR').toUpperCase() !== courtType) return false;
        return true;
      });

      const matchingCourts: Array<Record<string, unknown>> = [];

      for (const court of activeCourts) {
        if (date) {
          const cells = await this.timeSlotsService.getAvailabilityForDate(facility.id, court.id, date);
          const availableCells = cells.filter((cell) => {
            if (cell.status !== 'AVAILABLE' || cell.isBooked || !cell.isActive) return false;
            if (startTimeFrom && cell.startTime < startTimeFrom) return false;
            if (endTimeTo && cell.endTime > endTimeTo) return false;
            if (maxPriceVnd !== undefined && cell.price !== null) {
              // cell is 30-min discovery cell; hourly equivalent is cell.price * 2
              const hourlyEquivalent = cell.price * 2;
              if (cell.price > maxPriceVnd && hourlyEquivalent > maxPriceVnd) return false;
            }
            return true;
          });

          if (availableCells.length > 0) {
            const prices = availableCells
              .map((c) => (c.price !== null ? Math.round(c.price * 2) : null))
              .filter((p): p is number => p !== null);
            matchingCourts.push({
              courtId: court.id,
              courtName: court.name,
              courtType: court.courtType ?? 'INDOOR',
              availableHalfHourSlotsCount: availableCells.length,
              minHourlyPriceVnd: prices.length ? Math.min(...prices) : null,
              maxHourlyPriceVnd: prices.length ? Math.max(...prices) : null,
              sampleAvailableSlots: availableCells.slice(0, 6).map((c) => ({
                startTime: c.startTime,
                endTime: c.endTime,
                slotPriceVnd: c.price !== null ? Math.round(c.price) : null,
                hourlyRateVnd: c.price !== null ? Math.round(c.price * 2) : null,
              })),
            });
          }
        } else {
          const templates: any[] = court.timeSlots ?? [];
          const activeTemplates = templates.filter((t) => {
            if (t.isActive === false) return false;
            if (startTimeFrom && t.endTime <= startTimeFrom) return false;
            if (endTimeTo && t.startTime >= endTimeTo) return false;
            if (maxPriceVnd !== undefined && typeof t.price === 'number' && t.price > maxPriceVnd) {
              return false;
            }
            return true;
          });

          if (templates.length === 0) {
            if (maxPriceVnd === undefined) {
              matchingCourts.push({
                courtId: court.id,
                courtName: court.name,
                courtType: court.courtType ?? 'INDOOR',
                minPriceVnd: null,
                maxPriceVnd: null,
              });
            }
          } else if (activeTemplates.length > 0) {
            const prices = activeTemplates
              .map((t) => t.price)
              .filter((p): p is number => typeof p === 'number' && Number.isFinite(p));
            matchingCourts.push({
              courtId: court.id,
              courtName: court.name,
              courtType: court.courtType ?? 'INDOOR',
              minPriceVnd: prices.length ? Math.min(...prices) : null,
              maxPriceVnd: prices.length ? Math.max(...prices) : null,
              matchingTemplateCount: activeTemplates.length,
            });
          }
        }
      }

      if (matchingCourts.length > 0) {
        results.push({
          facilityId: facility.id,
          name: facility.name,
          address: facility.address,
          contactPhone: facility.contactPhone ?? null,
          matchingCourtsCount: matchingCourts.length,
          ...(nearby ? { distanceKm: Math.round(distanceKm(facility)! * 10) / 10 } : {}),
          courts: matchingCourts.slice(0, 5),
        });
      }
    }

    return {
      timezone: 'Asia/Ho_Chi_Minh',
      filtersApplied: {
        ...(nearby ? { radiusKm: nearby.radiusKm } : {}),
        facilityId: facilityId ?? null,
        districtOrKeyword: keyword ?? null,
        date: date ?? null,
        startTimeFrom: startTimeFrom ?? null,
        endTimeTo: endTimeTo ?? null,
        maxPriceVnd: maxPriceVnd ?? null,
        courtType: courtType ?? null,
      },
      totalMatchingFacilities: results.length,
      facilities: results,
    };
  }

  private async getMyBookings(
    caller: AiCallerContext,
    args: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    const statusFilter =
      typeof args.status === 'string' && args.status.trim() !== ''
        ? args.status.trim().toUpperCase()
        : undefined;
    if (
      statusFilter !== undefined &&
      !['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED'].includes(statusFilter)
    ) {
      throw new BadRequestException('Invalid booking status filter.');
    }

    const upcomingOnly = args.upcomingOnly === true;
    const rawLimit = args.limit !== undefined && args.limit !== null ? Number(args.limit) : 10;
    if (!Number.isInteger(rawLimit) || rawLimit < 1 || rawLimit > 20) {
      throw new BadRequestException('limit must be an integer between 1 and 20.');
    }

    // Strictly scoped to caller.userId from verified JWT
    const bookings = await this.bookingsService.findMyBookings(caller.userId);
    const now = new Date();

    const filtered = bookings.filter((b) => {
      if (statusFilter && b.status !== (statusFilter as BookingStatus)) return false;
      if (upcomingOnly && b.startTime <= now) return false;
      return true;
    });

    const items = filtered.slice(0, rawLimit).map((b) => {
      const startVn = vietnamTime(b.startTime);
      const endVn = vietnamTime(b.endTime);
      return {
        bookingId: b.id,
        status: b.status,
        date: startVn.date,
        startTime: startVn.time,
        endTime: endVn.time === '00:00' && endVn.date !== startVn.date ? '24:00' : endVn.time,
        totalPriceVnd: Math.round(b.totalPrice),
        courtId: b.courtId,
        courtName: b.court?.name ?? null,
        facilityId: b.court?.facilityId ?? null,
        facilityName: b.court?.facility?.name ?? null,
        facilityAddress: b.court?.facility?.address ?? null,
      };
    });

    return {
      timezone: 'Asia/Ho_Chi_Minh',
      totalMatchingBookings: filtered.length,
      bookings: items,
    };
  }

  private async recommendPlayers(
    caller: AiCallerContext,
    args: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    if (caller.role !== Role.PLAYER) {
      throw new ForbiddenException('Player recommendations are only available to PLAYER accounts.');
    }

    const maxDistanceKm =
      args.maxDistanceKm !== undefined && args.maxDistanceKm !== null ? Number(args.maxDistanceKm) : 10;
    if (!Number.isFinite(maxDistanceKm) || maxDistanceKm <= 0 || maxDistanceKm > 50) {
      throw new BadRequestException('maxDistanceKm must be between 0.5 and 50.');
    }

    const minSkillLevel =
      args.minSkillLevel !== undefined && args.minSkillLevel !== null ? Number(args.minSkillLevel) : undefined;
    const maxSkillLevel =
      args.maxSkillLevel !== undefined && args.maxSkillLevel !== null ? Number(args.maxSkillLevel) : undefined;

    if (
      minSkillLevel !== undefined &&
      (!Number.isInteger(minSkillLevel) || minSkillLevel < 1 || minSkillLevel > 5)
    ) {
      throw new BadRequestException('minSkillLevel must be an integer between 1 and 5.');
    }
    if (
      maxSkillLevel !== undefined &&
      (!Number.isInteger(maxSkillLevel) || maxSkillLevel < 1 || maxSkillLevel > 5)
    ) {
      throw new BadRequestException('maxSkillLevel must be an integer between 1 and 5.');
    }
    if (minSkillLevel !== undefined && maxSkillLevel !== undefined && minSkillLevel > maxSkillLevel) {
      throw new BadRequestException('minSkillLevel cannot be greater than maxSkillLevel.');
    }

    const limit = args.limit !== undefined && args.limit !== null ? Number(args.limit) : 5;
    if (!Number.isInteger(limit) || limit < 1 || limit > 10) {
      throw new BadRequestException('limit must be an integer between 1 and 10.');
    }

    let playingStyles: string[] | undefined;
    if (args.playingStyles !== undefined && args.playingStyles !== null) {
      if (!Array.isArray(args.playingStyles) || !args.playingStyles.every((s) => typeof s === 'string')) {
        throw new BadRequestException('playingStyles must be an array of strings.');
      }
      playingStyles = args.playingStyles.map((s) => s.trim()).filter(Boolean);
    }

    // Load caller's own saved location & availability from DB (never expose other players' GPS)
    const profile = await this.prisma.playerProfile.findUnique({
      where: { userId: caller.userId },
      select: { latitude: true, longitude: true },
    });

    if (!profile || profile.latitude === null || profile.longitude === null) {
      return {
        status: 'LOCATION_REQUIRED',
        message:
          'You have not saved your location yet. Please update your location in the Find Players / Map screen first.',
        recommendations: [],
      };
    }

    let availableTimeSlots = await this.availabilityService.getUpcomingTimeSlots(caller.userId, 7);
    if (availableTimeSlots.length === 0) {
      return {
        status: 'AVAILABILITY_REQUIRED',
        message:
          'You have no upcoming availability slots registered. Please add your weekly availability in Match Preferences first.',
        recommendations: [],
      };
    }

    // MatchmakingService persists recommendation history, so it must not be
    // called by the read-only assistant. Return only consented nearby players.
    const nearby = await this.candidatesService.findNearby(caller.userId, {
      radiusKm: maxDistanceKm,
      limit,
    });
    return {
      status: 'NEARBY_ONLY',
      message: playingStyles?.length
        ? 'Read-only nearby results; compatibility scores, availability and requested play styles are not evaluated.'
        : 'Read-only nearby results; compatibility scores and availability are not evaluated.',
      recommendations: nearby.candidates
        .filter((c) => (minSkillLevel === undefined || (c.skillLevel != null && Number(c.skillLevel) >= minSkillLevel)) &&
          (maxSkillLevel === undefined || (c.skillLevel != null && Number(c.skillLevel) <= maxSkillLevel)))
        .map((c) => ({
          userId: String(c.userId),
          displayName: c.nickname ?? c.fullName ?? `Player #${c.userId}`,
          skillLevel: c.skillLevel ?? null,
          distanceKm: c.distanceKm,
          matchScore: null,
          breakdown: null,
        })),
    };
  }

  private async getOwnerAnalytics(
    caller: AiCallerContext,
    args: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    // Strictly restricted to COURT_OWNER role
    if (caller.role !== Role.OWNER) {
      throw new ForbiddenException(
        'Access denied: Court Owner analytics and revenue data are restricted strictly to COURT_OWNER accounts.',
      );
    }

    const facilityId =
      args.facilityId !== undefined && args.facilityId !== null ? Number(args.facilityId) : undefined;
    if (facilityId !== undefined && (!Number.isInteger(facilityId) || facilityId < 1)) {
      throw new BadRequestException('facilityId must be a positive integer.');
    }

    const from = this.assertValidDate(args.from, 'from');
    const to = this.assertValidDate(args.to, 'to');

    // Verify ownership via FacilitiesService / RevenueAnalyticsService (throws ForbiddenException if facility belongs to another owner)
    const myFacilities = await this.facilitiesService.getMyFacilities(caller.userId);
    if (facilityId !== undefined) {
      const ownsFacility = myFacilities.some((f) => f.id === facilityId);
      if (!ownsFacility) {
        const exists = await this.prisma.facility.findUnique({
          where: { id: facilityId },
          select: { id: true, ownerId: true },
        });
        if (!exists) {
          throw new NotFoundException(`Facility ID ${facilityId} was not found.`);
        }
        throw new ForbiddenException(
          `Access denied: Facility ID ${facilityId} belongs to another Court Owner.`,
        );
      }
    }

    const [overview, utilization] = await Promise.all([
      this.revenueAnalyticsService.getOverview(
        { userId: caller.userId, role: caller.role },
        { facilityId, from, to },
      ),
      this.revenueAnalyticsService.getCourtUtilization(
        { userId: caller.userId, role: caller.role },
        { facilityId, from, to },
      ),
    ]);

    return {
      timezone: 'Asia/Ho_Chi_Minh',
      ownedFacilities: myFacilities.map((f) => ({
        facilityId: f.id,
        name: f.name,
        address: f.address,
        courtCount: f.courts?.length ?? 0,
      })),
      selectedFacilityId: facilityId ?? null,
      range: overview.range,
      grossBookedRevenueVnd: overview.grossBookedRevenue,
      totalBookings: overview.totalBookings,
      confirmedBookings: overview.confirmedBookings,
      bookingsByStatus: overview.byStatus,
      cancellationRate: overview.cancellationRate,
      averageBookingValueVnd: overview.averageBookingValue,
      bookedHours: overview.bookedHours,
      availableHours: overview.availableHours,
      occupancyRate: overview.occupancyRate,
      courtUtilization: utilization.courts.slice(0, 10),
    };
  }
}
