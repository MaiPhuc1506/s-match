import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { RecommendationOutcome } from '@prisma/client';
import { Type } from 'class-transformer';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';

export class ListHistoryQueryDto {
  @ApiPropertyOptional({ example: 1, description: 'Trang (bắt đầu từ 1)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @ApiPropertyOptional({ example: 20, description: 'Số phiên mỗi trang (mặc định 20, tối đa 50)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}

export class UpdateOutcomeDto {
  @ApiProperty({
    enum: RecommendationOutcome,
    description:
      'Kết quả mới. Cho phép: SHOWN→INVITED|DISMISSED, INVITED→ACCEPTED|DISMISSED. ACCEPTED/DISMISSED là trạng thái cuối.',
  })
  @IsEnum(RecommendationOutcome)
  outcome: RecommendationOutcome;
}
