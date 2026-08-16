import { Module } from '@nestjs/common';
import { SpotifyController } from './spotify.controller';
import { SpotifyService } from './spotify.service';
import { TokenCipher } from './token-cipher.service';

@Module({
  controllers: [SpotifyController],
  providers: [SpotifyService, TokenCipher],
  exports: [SpotifyService]
})
export class SpotifyModule {}
