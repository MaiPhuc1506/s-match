import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsNotEmpty, IsNumber, IsOptional, IsString, Min, Max } from 'class-validator';

export class CreateFacilityDto {
  @ApiProperty({ example: 'Sân Cầu Lông S-Match Đà Nẵng' })
  @IsString()
  @IsNotEmpty()
  name: string;

  @ApiProperty({ example: '123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng' })
  @IsString()
  @IsNotEmpty()
  address: string;

  @ApiPropertyOptional({ example: 16.0678 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  latitude?: number;

  @ApiPropertyOptional({ example: 108.2208 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  longitude?: number;

  @ApiPropertyOptional({ example: '0901234567' })
  @IsString()
  @IsOptional()
  contactPhone?: string;

  @ApiPropertyOptional({ example: 'Cụm sân tiêu chuẩn thảm thi đấu Yonex, có đèn LED chống lóa' })
  @IsString()
  @IsOptional()
  description?: string;
}
