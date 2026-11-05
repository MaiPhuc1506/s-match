import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsDateString, IsInt, IsOptional, Max, Min } from 'class-validator';

export class GetAnalyticsQueryDto {
  @ApiPropertyOptional({
    example: '2026-11-01T00:00:00.000Z',
    description: 'Mốc bắt đầu UTC theo ISO-8601. Khoảng báo cáo dùng [startDate, endDate).',
  })
  @IsOptional()
  @IsDateString({ strict: true })
  startDate?: string;

  @ApiPropertyOptional({
    example: '2026-12-01T00:00:00.000Z',
    description: 'Mốc kết thúc UTC theo ISO-8601 (không bao gồm).',
  })
  @IsOptional()
  @IsDateString({ strict: true })
  endDate?: string;

  @ApiPropertyOptional({
    example: 12,
    minimum: 1,
    maximum: 2147483647,
    description: 'Lọc theo Facility. Owner chỉ được dùng ID thuộc quyền sở hữu của mình.',
  })
  @IsOptional()
  @Transform(({ value }) => value === undefined ? undefined : Number(value))
  @IsInt()
  @Min(1)
  @Max(2147483647)
  facilityId?: number;
}
