import { ApiProperty } from '@nestjs/swagger';
import { IsDateString, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';

export class CreateBookingDto {
  @ApiProperty({ example: 1, description: 'ID của sân muốn đặt' })
  @IsNumber()
  @IsNotEmpty()
  courtId: number;

  @ApiProperty({
    example: '2026-10-01T08:00:00.000Z',
    description: 'Thời gian bắt đầu (ISO 8601)',
  })
  @IsDateString()
  @IsNotEmpty()
  startTime: string;

  @ApiProperty({
    example: '2026-10-01T10:00:00.000Z',
    description: 'Thời gian kết thúc (ISO 8601)',
  })
  @IsDateString()
  @IsNotEmpty()
  endTime: string;

  @ApiProperty({ example: 120000, description: 'Tổng tiền đặt sân (VND)', required: false })
  @IsNumber()
  @Min(0)
  @IsOptional()
  totalPrice?: number;

  @ApiProperty({ example: 'Đặt sân chơi cuối tuần', description: 'Ghi chú thêm', required: false })
  @IsString()
  @IsOptional()
  note?: string;
}