import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsString, Max, MaxLength, Min, ValidateIf } from 'class-validator';

export class SubmitFeedbackDto {
  @ApiProperty({ minimum: 1, maximum: 2147483647 })
  @IsInt()
  @Min(1)
  @Max(2147483647)
  recipientUserId: number;

  @ApiProperty({ minimum: 1, maximum: 5 })
  @IsInt()
  @Min(1)
  @Max(5)
  rating: number;

  @ApiPropertyOptional({ maxLength: 500, nullable: false })
  @ValidateIf((_object, value) => value !== undefined)
  @IsString()
  @MaxLength(500)
  comment?: string;
}
