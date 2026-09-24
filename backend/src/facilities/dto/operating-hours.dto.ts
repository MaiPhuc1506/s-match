import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsInt,
  IsString,
  Matches,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;
const TIME_MESSAGE = 'Giờ phải theo định dạng HH:mm (ví dụ: 06:00)';

export class UpsertOperatingHourDto {
  @ApiProperty({ example: 1, description: '0 = Chủ Nhật ... 6 = Thứ 7' })
  @IsInt()
  @Min(0)
  @Max(6)
  dayOfWeek: number;

  @ApiProperty({ example: '06:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  openTime: string;

  @ApiProperty({ example: '22:00' })
  @IsString()
  @Matches(TIME_PATTERN, { message: TIME_MESSAGE })
  closeTime: string;
}

export class BulkUpsertOperatingHoursDto {
  @ApiProperty({ type: [UpsertOperatingHourDto], description: 'Danh sách giờ hoạt động cho một hoặc nhiều ngày trong tuần' })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(7)
  @ValidateNested({ each: true })
  @Type(() => UpsertOperatingHourDto)
  days: UpsertOperatingHourDto[];
}
