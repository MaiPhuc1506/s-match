import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayNotEmpty, IsArray, IsDateString, IsDefined, IsInt, IsNumber, IsObject,
  IsString, Matches, Max, Min, ValidateIf, ValidateNested,
} from 'class-validator';

export class FindPlayerLocationDto {
  @ApiProperty({ minimum: -90, maximum: 90 })
  @IsNumber()
  @Min(-90)
  @Max(90)
  latitude: number;

  @ApiProperty({ minimum: -180, maximum: 180 })
  @IsNumber()
  @Min(-180)
  @Max(180)
  longitude: number;
}

// Temporary Flutter contract: confirm field names/time-slot semantics with Phuc and Dung.
export class FindPlayerDto {
  @ApiProperty({ type: [String], example: ['2026-10-20T18:00:00Z'] })
  @IsArray()
  @ArrayNotEmpty()
  @IsDateString({ strict: true }, { each: true })
  @Matches(/T.*(?:Z|[+-]\d{2}:\d{2})$/, { each: true })
  availableTimeSlots: string[];

  @ApiProperty({ type: FindPlayerLocationDto })
  @IsDefined()
  @IsObject()
  @ValidateNested()
  @Type(() => FindPlayerLocationDto)
  location: FindPlayerLocationDto;

  @ApiProperty({ minimum: 0, example: 10 })
  @IsNumber()
  @Min(0)
  maxDistanceKm: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @ValidateIf((_object, value) => value !== undefined)
  @IsInt()
  @Min(1)
  @Max(5)
  minSkillLevel?: number;

  @ApiPropertyOptional({ minimum: 1, maximum: 5 })
  @ValidateIf((_object, value) => value !== undefined)
  @IsInt()
  @Min(1)
  @Max(5)
  maxSkillLevel?: number;

  @ApiPropertyOptional({ type: [String] })
  @ValidateIf((_object, value) => value !== undefined)
  @IsArray()
  @IsString({ each: true })
  playingStyles?: string[];
}
