import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { AuthModule } from './auth/auth.module.js';
import { UsersModule } from './users/users.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { PlayersModule } from './players/players.module';
import { AvailabilityPreferenceModule } from './availability-preference/availability-preference.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
    AuthModule,
    PlayersModule,
    AvailabilityPreferenceModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}