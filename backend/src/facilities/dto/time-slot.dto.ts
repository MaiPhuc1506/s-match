import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';

const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;
const TIME_MESSAGE = 'Giờ phải theo định dạng HH:mm (ví dụ: 18:00)';

export class CreateTimeSlotDto {
  @ApiProperty({ example: 1, description: '0 = Chủ Nhật ... 6 = Thứ 7' })
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek: number;

  @ApiProperty({ example: '18:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  startTime: string;

  @ApiProperty({ example: '19:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  endTime: string;

  @ApiProperty({ example: 240000, description: 'Giá cho khung giờ này (VNĐ)' })
  @IsNumber()
  @Min(0)
  price: number;
}

export class UpdateTimeSlotDto {
  @ApiPropertyOptional({ example: '18:00' })
  @IsOptional()
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  startTime?: string;

  @ApiPropertyOptional({ example: '19:00' })
  @IsOptional()
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  endTime?: string;

  @ApiPropertyOptional({ example: 240000 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  price?: number;

  @ApiPropertyOptional({ example: true, description: 'Tắt/bật khung giờ mà không cần xoá' })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
