import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsOptional, IsString } from 'class-validator';
import { CourtStatus } from '@prisma/client';

export class UpdateCourtDto {
  @ApiPropertyOptional({ example: 'Sân 1 (VIP)' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: 'INDOOR', description: 'INDOOR hoặc OUTDOOR' })
  @IsString()
  @IsOptional()
  courtType?: string;

  @ApiPropertyOptional({ enum: CourtStatus, description: 'ACTIVE, MAINTENANCE hoặc INACTIVE' })
  @IsEnum(CourtStatus)
  @IsOptional()
  status?: CourtStatus;
}
