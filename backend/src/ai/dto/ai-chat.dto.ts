import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  IsNumber,
  Min,
  Max,
  ValidateNested,
} from 'class-validator';

export class AiChatHistoryItemDto {
  @ApiProperty({ enum: ['user', 'assistant'] })
  @IsString()
  @IsIn(['user', 'assistant'])
  role: 'user' | 'assistant';

  @ApiProperty({ maxLength: 1000 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  content: string;
}

export class NearbyCourtSearchDto {
  @IsNumber() @Min(-90) @Max(90) latitude: number;
  @IsNumber() @Min(-180) @Max(180) longitude: number;
  @IsNumber() @Min(0.05) @Max(100) radiusKm: number;
}

export class AiChatRequestDto {
  @ApiProperty({ example: 'Find indoor courts under 120,000 VND tomorrow evening', maxLength: 1000 })
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  message: string;

  @ApiPropertyOptional({ type: [AiChatHistoryItemDto] })
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => AiChatHistoryItemDto)
  history?: AiChatHistoryItemDto[];

  @ApiPropertyOptional({ type: NearbyCourtSearchDto })
  @IsOptional() @ValidateNested() @Type(() => NearbyCourtSearchDto)
  nearby?: NearbyCourtSearchDto;
}

export class AiChatResponseDto {
  @ApiProperty()
  reply: string;

  @ApiProperty({ type: [String] })
  toolsUsed: string[];

  @ApiProperty()
  provider: string;

  @ApiPropertyOptional()
  fallback?: boolean;

  @ApiPropertyOptional({ type: [Object] })
  courtResults?: Record<string, unknown>[];
}
