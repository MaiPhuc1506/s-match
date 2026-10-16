import { ApiPropertyOptional, OmitType, PartialType } from '@nestjs/swagger';
import { IsEnum, IsInt, IsNumber, IsOptional, Max, Min, ValidateIf } from 'class-validator';
import { CreateMatchDto, MatchPrivacyDto } from './create-match.dto';

// Exclude fields with POST initializers before inheriting validation. PATCH must
// never acquire values that were not sent by the client.
export class UpdateMatchDto extends PartialType(
  OmitType(CreateMatchDto, ['privacy', 'maxPlayers', 'feePerPlayer'] as const),
  { skipNullProperties: false },
) {
  @ApiPropertyOptional({ enum: MatchPrivacyDto, nullable: false })
  @ValidateIf((_object, value) => value !== undefined)
  @IsEnum(MatchPrivacyDto)
  privacy?: MatchPrivacyDto;

  @ApiPropertyOptional({ example: 4, minimum: 2, maximum: 2147483647, nullable: false })
  @ValidateIf((_object, value) => value !== undefined)
  @IsInt()
  @Max(2147483647)
  @Min(2, { message: 'Số lượng người chơi tối thiểu phải là 2' })
  maxPlayers?: number;

  // Preserve the existing nullable scalar semantics; null explicitly clears the
  // fee, whereas omission leaves it unchanged. No new pricing rules are added.
  @ApiPropertyOptional({ example: 50000, nullable: true })
  @IsOptional()
  @IsNumber()
  feePerPlayer?: number | null;
}
