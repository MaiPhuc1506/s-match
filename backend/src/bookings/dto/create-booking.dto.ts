import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsNotEmpty, IsNumber, IsOptional, IsString } from 'class-validator';

export class CreateBookingDto {
  @ApiProperty({ example: 1, description: 'ID của sân muốn đặt' })
  @IsNumber()
  @IsNotEmpty()
  courtId: number;

  @ApiProperty({
    example: '2026-10-10T08:00:00.000Z',
    description: 'Thời gian bắt đầu (ISO 8601)',
  })
  @IsDateString()
  @IsNotEmpty()
  startTime: string;

  @ApiProperty({
    example: '2026-10-10T10:00:00.000Z',
    description: 'Thời gian kết thúc (ISO 8601)',
  })
  @IsDateString()
  @IsNotEmpty()
  endTime: string;

  @ApiProperty({ example: 'Đặt sân chơi cuối tuần', description: 'Ghi chú thêm', required: false })
  @IsString()
  @IsOptional()
  note?: string;
}