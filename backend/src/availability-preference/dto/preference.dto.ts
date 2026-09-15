import { ApiProperty } from '@nestjs/swagger';
import { MatchMode, MatchPurpose } from '@prisma/client';
import {
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

export class UpsertPreferenceDto {
  @ApiProperty({ enum: MatchMode, default: MatchMode.DOUBLES })
  @IsEnum(MatchMode, { message: 'preferredMode phải là SINGLES hoặc DOUBLES' })
  preferredMode: MatchMode;

  @ApiProperty({ enum: MatchPurpose, default: MatchPurpose.CASUAL })
  @IsEnum(MatchPurpose, {
    message: 'purpose phải là CASUAL, TRAINING hoặc COMPETITIVE',
  })
  purpose: MatchPurpose;

  @ApiProperty({
    example: 2,
    description: 'Trình độ đối thủ mong muốn (thấp nhất), thang 1-5',
  })
  @IsInt({ message: 'minSkillLevel phải là số nguyên' })
  @Min(1, { message: 'minSkillLevel phải từ 1 đến 5' })
  @Max(5, { message: 'minSkillLevel phải từ 1 đến 5' })
  minSkillLevel: number;

  @ApiProperty({
    example: 4,
    description: 'Trình độ đối thủ mong muốn (cao nhất), thang 1-5',
  })
  @IsInt({ message: 'maxSkillLevel phải là số nguyên' })
  @Min(1, { message: 'maxSkillLevel phải từ 1 đến 5' })
  @Max(5, { message: 'maxSkillLevel phải từ 1 đến 5' })
  maxSkillLevel: number;

  @ApiProperty({ example: 10, description: 'Khoảng cách tối đa (km)' })
  @IsNumber({}, { message: 'maxDistanceKm phải là số' })
  @Min(0, { message: 'maxDistanceKm không được âm' })
  maxDistanceKm: number;
}
