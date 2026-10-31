import { ApiProperty } from '@nestjs/swagger';

export class FeedbackResponseDto {
  @ApiProperty()
  id: number;

  @ApiProperty()
  matchId: number;

  @ApiProperty()
  senderUserId: number;

  @ApiProperty()
  recipientUserId: number;

  @ApiProperty({ minimum: 1, maximum: 5 })
  rating: number;

  @ApiProperty({ type: String, nullable: true, maxLength: 500 })
  comment: string | null;

  @ApiProperty({ type: String, format: 'date-time' })
  createdAt: Date;
}
