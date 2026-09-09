import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';

// SMM-8 — User Database & Backend Connection.
// This module intentionally only wires up the database connection (PrismaModule)
// and the User table access layer (UsersModule). Auth (SMM-6), Matchmaking Service
// Setup (SMM-7), and every later-sprint module (Court, Booking, Player Profile, ...)
// are separate tickets and are not included here — add them back with `imports: [...]`
// as their own tickets land.
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    UsersModule,
  ],
})
export class AppModule {}
