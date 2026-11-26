import { IsEmail, IsString, Matches, MaxLength } from 'class-validator';
export class RecoveryRequestDto { @IsEmail() @MaxLength(254) email: string; }
export class RecoveryVerifyDto extends RecoveryRequestDto { @IsString() @Matches(/^\d{6}$/) code: string; }
export class RecoveryResetDto extends RecoveryRequestDto {
  @IsString() @Matches(/^[0-9a-f]{64}$/) resetToken: string;
  @IsString() @MaxLength(72) @Matches(/^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,72}$/s) password: string;
}
