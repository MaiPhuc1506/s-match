import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { CourtStatus } from '@prisma/client';

export class AnalyticsRangeResponseDto {
  @ApiPropertyOptional({ nullable: true, format: 'date-time' })
  startDate: string | null;

  @ApiPropertyOptional({ nullable: true, format: 'date-time' })
  endDate: string | null;

  @ApiProperty({ example: 'UTC' })
  timezone: 'UTC';
}

export class BookingStatusBreakdownDto {
  @ApiPropertyOptional({ nullable: true }) pending: number | null;
  @ApiPropertyOptional({ nullable: true }) confirmed: number | null;
  @ApiPropertyOptional({ nullable: true }) cancelled: number | null;
  @ApiPropertyOptional({ nullable: true }) completed: number | null;
}

export class AnalyticsSummaryDto {
  @ApiProperty({ description: 'Số Facility trong phạm vi đã được xác thực.' })
  totalFacilities: number;

  @ApiPropertyOptional({ nullable: true, description: 'Chưa có khái niệm active User trong schema hiện tại.' })
  totalActiveUsers: number | null;

  @ApiPropertyOptional({ nullable: true }) totalBookings: number | null;
  @ApiProperty({ type: BookingStatusBreakdownDto }) bookingStatusBreakdown: BookingStatusBreakdownDto;
  @ApiPropertyOptional({ nullable: true, description: 'Reserved occupancy, không phải actual usage.' })
  reservedOccupancyRatePercent: number | null;
  @ApiPropertyOptional({ nullable: true, description: 'Gross booked revenue; không phải doanh thu đã thanh toán.' })
  grossBookedRevenue: number | null;
}

export class AnalyticsOverviewResponseDto {
  @ApiProperty({ enum: ['OWNER', 'ADMIN'] }) scope: 'OWNER' | 'ADMIN';
  @ApiProperty({ type: AnalyticsRangeResponseDto }) range: AnalyticsRangeResponseDto;
  @ApiProperty({ enum: ['PENDING_SMM_40', 'READY'] }) dataStatus: 'PENDING_SMM_40' | 'READY';
  @ApiProperty({ type: AnalyticsSummaryDto }) summary: AnalyticsSummaryDto;
}

export class CourtPerformanceResponseDto {
  @ApiProperty() courtId: number;
  @ApiProperty() facilityId: number;
  @ApiProperty() courtName: string;
  @ApiProperty({ enum: CourtStatus }) status: CourtStatus;
  @ApiPropertyOptional({ nullable: true }) bookingCount: number | null;
  @ApiPropertyOptional({ nullable: true }) confirmedBookings: number | null;
  @ApiPropertyOptional({ nullable: true }) cancelledBookings: number | null;
  @ApiPropertyOptional({ nullable: true }) completedBookings: number | null;
  @ApiPropertyOptional({ nullable: true }) reservedHours: number | null;
  @ApiPropertyOptional({ nullable: true }) availableHours: number | null;
  @ApiPropertyOptional({ nullable: true }) reservedOccupancyRatePercent: number | null;
  @ApiPropertyOptional({ nullable: true }) grossBookedRevenue: number | null;
}

export class CourtPerformanceListResponseDto {
  @ApiProperty({ type: AnalyticsRangeResponseDto }) range: AnalyticsRangeResponseDto;
  @ApiProperty({ enum: ['PENDING_SMM_40', 'READY'] }) dataStatus: 'PENDING_SMM_40' | 'READY';
  @ApiProperty({ type: [CourtPerformanceResponseDto] }) courts: CourtPerformanceResponseDto[];
}
