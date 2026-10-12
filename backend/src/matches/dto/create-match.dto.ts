import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export enum MatchPrivacyDto {
  PRIVATE = 'PRIVATE',
  OPEN = 'OPEN',
}

export class CreateMatchDto {
  @ApiProperty({ example: 'Kèo giao lưu cầu lông tối thứ 5' })
  @IsString()
  @IsNotEmpty({ message: 'Tiêu đề trận đấu không được để trống' })
  title: string;

  @ApiPropertyOptional({ example: 'Trình độ trung bình khá, tìm 2 bạn đánh đôi' })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiPropertyOptional({ enum: MatchPrivacyDto, default: MatchPrivacyDto.OPEN })
  @IsEnum(MatchPrivacyDto)
  @IsOptional()
  privacy?: MatchPrivacyDto = MatchPrivacyDto.OPEN;

  @ApiPropertyOptional({ example: 1, description: 'ID đơn đặt sân (nếu có)' })
  @IsInt()
  @IsOptional()
  bookingId?: number;

  @ApiProperty({ example: '2026-10-10T18:00:00.000Z' })
  @IsDateString()
  startTime: string;

  @ApiProperty({ example: '2026-10-10T20:00:00.000Z' })
  @IsDateString()
  endTime: string;

  @ApiPropertyOptional({ example: 'Sân Cầu Lông S-Match Đà Nẵng, Sân 1' })
  @IsString()
  @IsOptional()
  location?: string;

  @ApiPropertyOptional({ example: 4, default: 4 })
  @IsInt()
  @Min(2, { message: 'Số lượng người chơi tối thiểu phải là 2' })
  @IsOptional()
  maxPlayers?: number = 4;

  @ApiPropertyOptional({ example: 50000, default: 0 })
  @IsNumber()
  @IsOptional()
  feePerPlayer?: number = 0;
}