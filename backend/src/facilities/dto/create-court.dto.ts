import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';
import { CourtStatus } from '@prisma/client';

export class CreateCourtDto {
  @ApiProperty({ example: 'Sân 1 (VIP)' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiPropertyOptional({ example: 'INDOOR', description: 'INDOOR hoặc OUTDOOR' })
  @IsString()
  @IsOptional()
  courtType?: string;

  @ApiPropertyOptional({ enum: CourtStatus, default: CourtStatus.ACTIVE })
  @IsEnum(CourtStatus)
  @IsOptional()
  status?: CourtStatus;
}