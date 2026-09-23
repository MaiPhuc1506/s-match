import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsNumber, IsOptional, IsString } from 'class-validator';

export class UpdateFacilityDto {
  @ApiPropertyOptional({ example: 'Sân Cầu Lông S-Match Đà Nẵng' })
  @IsString()
  @IsOptional()
  name?: string;

  @ApiPropertyOptional({ example: '456 Trần Phú, Hải Châu, Đà Nẵng' })
  @IsString()
  @IsOptional()
  address?: string;

  @ApiPropertyOptional({ example: 16.0678 })
  @IsNumber()
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ example: 108.2208 })
  @IsNumber()
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional({ example: '0901234567' })
  @IsString()
  @IsOptional()
  contactPhone?: string;

  @ApiPropertyOptional({ example: 'Cụm sân tiêu chuẩn thảm thi đấu Yonex' })
  @IsString()
  @IsOptional()
  description?: string;
}
