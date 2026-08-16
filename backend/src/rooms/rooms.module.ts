import { Module } from '@nestjs/common';
import { RoomsController } from './rooms.controller';
import { RoomsGateway } from './rooms.gateway';
import { RoomsService } from './rooms.service';
import { SpotifyModule } from '../spotify/spotify.module';
import { AuthModule } from '../auth/auth.module';

@Module({ imports: [AuthModule, SpotifyModule], controllers: [RoomsController], providers: [RoomsService, RoomsGateway] })
export class RoomsModule {}
