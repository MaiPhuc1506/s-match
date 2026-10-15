import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsNumber, IsOptional, Max, Min } from 'class-validator';

export class UpdateLocationDto {
  @ApiProperty({ example: 16.047079, description: 'Vĩ độ (-90 → 90)' })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @ApiProperty({ example: 108.20623, description: 'Kinh độ (-180 → 180)' })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;
}

export class CandidateQueryDto {
  @ApiPropertyOptional({
    example: 10,
    description: 'Bán kính tìm kiếm (km). Mặc định lấy maxDistanceKm trong PlayingPreference, hoặc 10.',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  @Max(100)
  radiusKm?: number;

  @ApiPropertyOptional({ example: 20, description: 'Số ứng viên tối đa (mặc định 20, tối đa 100)' })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(100)
  limit?: number;

  @ApiPropertyOptional({
    example: 5,
    description: 'Top-K kết quả Matchmaking Service trả về (mặc định 5, tối đa 20)',
  })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(20)
  topK?: number;
}
