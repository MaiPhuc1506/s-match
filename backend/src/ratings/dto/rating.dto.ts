import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Transform, Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

const trimString = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export const COMMENT_MAX_LENGTH = 500;

export class CreateRatingDto {
  @ApiProperty({ example: 12, description: 'ID trận đấu đã diễn ra' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  matchId: number;

  @ApiProperty({ example: 7, description: 'ID người chơi được đánh giá (cùng trận, khác bản thân)' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  ratedUserId: number;

  @ApiProperty({ example: 5, minimum: 1, maximum: 5, description: 'Điểm tổng thể 1-5' })
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  score: number;

  @ApiPropertyOptional({ example: 4, minimum: 1, maximum: 5, description: 'Đúng giờ 1-5' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  punctuality?: number;

  @ApiPropertyOptional({ example: 5, minimum: 1, maximum: 5, description: 'Tinh thần thi đấu / thái độ 1-5' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  sportsmanship?: number;

  @ApiPropertyOptional({ example: 'Chơi nhiệt tình, đến đúng giờ.', maxLength: COMMENT_MAX_LENGTH })
  @IsOptional()
  @Transform(trimString)
  @IsString()
  @MaxLength(COMMENT_MAX_LENGTH)
  comment?: string;
}

export class UpdateRatingDto {
  @ApiPropertyOptional({ example: 4, minimum: 1, maximum: 5 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  score?: number;

  @ApiPropertyOptional({ example: 4, minimum: 1, maximum: 5 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  punctuality?: number;

  @ApiPropertyOptional({ example: 5, minimum: 1, maximum: 5 })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  sportsmanship?: number;

  @ApiPropertyOptional({ description: 'Chuỗi rỗng để xoá nhận xét', maxLength: COMMENT_MAX_LENGTH })
  @IsOptional()
  @Transform(trimString)
  @IsString()
  @MaxLength(COMMENT_MAX_LENGTH)
  comment?: string;
}

export class ListRatingsQueryDto {
  @ApiPropertyOptional({ example: 1, description: 'Trang (bắt đầu từ 1)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @ApiPropertyOptional({ example: 20, description: 'Số đánh giá mỗi trang (mặc định 20, tối đa 50)' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;
}
