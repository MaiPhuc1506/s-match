import { ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, Matches, Min } from 'class-validator';

const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;

export class AnalyticsQueryDto {
  @ApiPropertyOptional({
    example: '2026-10-01',
    description: 'Ngày bắt đầu (bao gồm, giờ VN, YYYY-MM-DD). Mặc định: 30 ngày gần nhất.',
  })
  @IsOptional()
  @Matches(DATE_REGEX, { message: 'from phải có định dạng YYYY-MM-DD' })
  from?: string;

  @ApiPropertyOptional({
    example: '2026-10-31',
    description: 'Ngày kết thúc (bao gồm, giờ VN, YYYY-MM-DD). Mặc định: hôm nay. Tối đa 366 ngày.',
  })
  @IsOptional()
  @Matches(DATE_REGEX, { message: 'to phải có định dạng YYYY-MM-DD' })
  to?: string;

  @ApiPropertyOptional({
    example: 1,
    description: 'Chỉ thống kê một cơ sở. Chủ sân chỉ được chọn cơ sở của mình; bỏ trống = tất cả cơ sở của mình (ADMIN: toàn hệ thống).',
  })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  facilityId?: number;
}

export class RevenueTrendQueryDto extends AnalyticsQueryDto {
  @ApiPropertyOptional({ enum: ['day', 'week', 'month'], default: 'day', description: 'Độ chi tiết của chuỗi thời gian (tuần bắt đầu từ Thứ 2).' })
  @IsOptional()
  @IsIn(['day', 'week', 'month'])
  granularity?: 'day' | 'week' | 'month';
}
