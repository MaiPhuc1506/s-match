import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { MatchMode, MatchPurpose } from '@prisma/client';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';

export class CreateOpenMatchDto {
  @ApiProperty({ enum: MatchMode, default: MatchMode.DOUBLES })
  @IsEnum(MatchMode)
  mode: MatchMode;

  @ApiProperty({ enum: MatchPurpose, default: MatchPurpose.CASUAL })
  @IsEnum(MatchPurpose)
  purpose: MatchPurpose;

  @ApiProperty({ example: 2, description: 'Số người cần mời thêm (không tính host)' })
  @IsInt()
  @Min(1)
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
  @ApiPropertyOptional({ enum: MatchMode })
  @IsOptional()
  @IsEnum(MatchMode)
  mode?: MatchMode;

  @ApiPropertyOptional({ enum: MatchPurpose })
  @IsOptional()
  @IsEnum(MatchPurpose)
  purpose?: MatchPurpose;
}
