import { ApiProperty } from '@nestjs/swagger';
import {
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  Min,
} from 'class-validator';

const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;
const TIME_MESSAGE = 'Giờ phải theo định dạng HH:mm (ví dụ: 18:00)';

export class CreateAvailabilityDto {
  @ApiProperty({ example: 1, description: '0 = Chủ nhật ... 6 = Thứ 7' })
  @IsInt({ message: 'dayOfWeek phải là số nguyên' })
  @Min(0, { message: 'dayOfWeek phải từ 0 đến 6' })
  @Max(6, { message: 'dayOfWeek phải từ 0 đến 6' })
  dayOfWeek: number;

  @ApiProperty({ example: '18:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  startTime: string;

  @ApiProperty({ example: '21:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  endTime: string;
}

export class UpdateAvailabilityDto {
  @ApiProperty({ example: 1, required: false })
  @IsOptional()
  @IsInt({ message: 'dayOfWeek phải là số nguyên' })
  @Min(0, { message: 'dayOfWeek phải từ 0 đến 6' })
  @Max(6, { message: 'dayOfWeek phải từ 0 đến 6' })
  dayOfWeek?: number;

  @ApiProperty({ example: '18:00', required: false })
  @IsOptional()
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  startTime?: string;

  @ApiProperty({ example: '21:00', required: false })
  @IsOptional()
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  endTime?: string;
}
