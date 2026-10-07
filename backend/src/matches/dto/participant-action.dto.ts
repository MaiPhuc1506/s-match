import { ApiProperty } from '@nestjs/swagger';
import { IsInt, IsNotEmpty } from 'class-validator';

export class InviteUserDto {
  @ApiProperty({ example: 2, description: 'ID người chơi muốn mời' })
  @IsInt()
  @IsNotEmpty({ message: 'userId không được để trống' })
  targetUserId: number;
}