import { ApiPropertyOptional } from '@nestjs/swagger';
import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsString } from 'class-validator';

export class UpdateProfileDto {
  @ApiPropertyOptional({ example: 'Nguyễn Văn A' })
  @IsOptional()
  @IsString()
  fullName?: string;

  @ApiPropertyOptional({ example: '0901234567' })
  @Transform(({ value, obj }) => value ?? obj?.phoneNumber)
  @IsOptional()
  @IsString()
  phone?: string;

  @ApiPropertyOptional({
    example: '0901234567',
    description: 'Alias cho phone (tương thích Mobile App)',
  })
  @IsOptional()
  @IsString()
  phoneNumber?: string;

  @ApiPropertyOptional({ example: 'Striker99' })
  @IsOptional()
  @IsString()
  nickname?: string;

  @ApiPropertyOptional({ example: 'https://example.com/avatar.png' })
  @IsOptional()
  @IsString()
  avatarUrl?: string;

  @ApiPropertyOptional({
    example: 'INTERMEDIATE',
    enum: ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'],
    description: 'BEGINNER | INTERMEDIATE | ADVANCED',
  })
  @IsOptional()
  @IsString()
  @IsIn(['BEGINNER', 'INTERMEDIATE', 'ADVANCED'], {
    message: 'skillLevel phải là BEGINNER, INTERMEDIATE hoặc ADVANCED',
  })
  skillLevel?: string;

  @ApiPropertyOptional({ example: 'Thích giao lưu cầu lông/bóng đá cuối tuần' })
  @IsOptional()
  @IsString()
  bio?: string;

  @ApiPropertyOptional({ example: 'Nam' })
  @IsOptional()
  @IsString()
  gender?: string;
}