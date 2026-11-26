import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { AuthTokensService } from './auth-tokens.service';
import { AUTH_JWT_CONFIG, createAuthJwtConfig } from './jwt.config';
import { PasswordRecoveryService } from './password-recovery.service';
import { PasswordRecoveryController } from './password-recovery.controller';

@Global()
@Module({
  imports: [
    ConfigModule,
    JwtModule.register({
      global: true,
    }),
  ],
  controllers: [AuthController, PasswordRecoveryController],
  providers: [
    { provide: AUTH_JWT_CONFIG, inject: [ConfigService], useFactory: createAuthJwtConfig },
    AuthTokensService,
    PasswordRecoveryService,
    AuthService,
  ],
  exports: [AuthService, AuthTokensService],
})
export class AuthModule {}
