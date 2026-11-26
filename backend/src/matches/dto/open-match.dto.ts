import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MatchMode, MatchPurpose } from '@prisma/client';
import { IsEnum, IsInt, IsNumber, IsOptional, IsString, Matches, Max, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class CreateOpenMatchDto {
  @ApiPropertyOptional({ description: 'Optional match preferences' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;
  @ApiProperty({ enum: MatchMode, default: MatchMode.DOUBLES })
  @IsEnum(MatchMode)
  mode: MatchMode;

  @ApiProperty({ enum: MatchPurpose, default: MatchPurpose.CASUAL })
  @IsEnum(MatchPurpose)
  purpose: MatchPurpose;

  @ApiProperty({ example: 2, minimum: 1, maximum: 2147483646, description: 'Số người cần mời thêm (không tính host)' })
  @IsInt()
  @Min(1)
  @Max(2147483646)
  neededPlayers: number;

  @ApiProperty({ example: 2, description: 'Trình độ đối phương mong muốn (thấp nhất), thang 1-5' })
  @IsInt()
  @Min(1)
  @Max(5)
  minSkillLevel: number;

  @ApiProperty({ example: 4, description: 'Trình độ đối phương mong muốn (cao nhất), thang 1-5' })
  @IsInt()
  @Min(1)
  @Max(5)
  maxSkillLevel: number;
}

export class QueryOpenMatchDto {
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) date?: string;
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) @Max(5) skill?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(-90) @Max(90) latitude?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(-180) @Max(180) longitude?: number;
  @IsOptional() @Type(() => Number) @IsNumber() @Min(0.1) @Max(500) distanceKm?: number;
  @ApiPropertyOptional({ enum: MatchMode })
  @IsOptional()
  @IsEnum(MatchMode)
  mode?: MatchMode;

  @ApiPropertyOptional({ enum: MatchPurpose })
  @IsOptional()
  @IsEnum(MatchPurpose)
  purpose?: MatchPurpose;
}
