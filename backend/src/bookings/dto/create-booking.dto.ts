import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsNotEmpty, IsInt, Min, Matches, IsOptional, IsString } from 'class-validator';

export class CreateBookingDto {
  @ApiProperty({ example: 1, description: 'ID của sân muốn đặt' })
  @IsInt()
  @Min(1)
  @IsNotEmpty()
  courtId: number;

  @ApiProperty({ required: false, description: 'Cơ sở đang được chọn trên ứng dụng' })
  @IsOptional()
  @IsInt()
  @Min(1)
  facilityId?: number;

  @ApiProperty({
    example: '2026-10-10T08:00:00.000Z',
    description: 'Thời gian bắt đầu (ISO 8601)',
  })
  @IsDateString({ strict: true })
  @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/, { message: 'Thời gian phải bao gồm múi giờ' })
  @IsNotEmpty()
  startTime: string;

  @ApiProperty({
    example: '2026-10-10T10:00:00.000Z',
    description: 'Thời gian kết thúc (ISO 8601)',
  })
  @IsDateString({ strict: true })
  @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/, { message: 'Thời gian phải bao gồm múi giờ' })
  @IsNotEmpty()
  endTime: string;

  @ApiProperty({ example: 'Đặt sân chơi cuối tuần', description: 'Ghi chú thêm', required: false })
  @IsString()
  @IsOptional()
  note?: string;
}