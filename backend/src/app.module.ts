import { APP_GUARD } from '@nestjs/core';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import * as Joi from 'joi';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { PrismaService } from './prisma.service';
import { RoomsModule } from './rooms/rooms.module';
import { SpotifyModule } from './spotify/spotify.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validationSchema: Joi.object({
        DATABASE_URL: Joi.string().uri().required(),
        JWT_SECRET: Joi.string().min(32).required(),
        TOKEN_ENCRYPTION_KEY: Joi.string().required(),
        SPOTIFY_CLIENT_ID: Joi.string().required(),
        SPOTIFY_REDIRECT_URI: Joi.string().uri().required(),
        MOBILE_CALLBACK_URI: Joi.string().uri().required(),
        ALLOWED_ORIGINS: Joi.string().required(),
        PORT: Joi.number().port().default(3000)
      })
    }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    AuthModule,
    SpotifyModule,
    RoomsModule
  ],
  providers: [PrismaService, { provide: APP_GUARD, useClass: ThrottlerGuard }]
})
export class AppModule {}
