import { Body, Controller, Get, Param, Post, Query, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { IsString, Length, Matches } from 'class-validator';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { SpotifyService } from './spotify.service';

class CreatePkceSessionDto {
  @IsString()
  @Length(43, 128)
  @Matches(/^[A-Za-z0-9\-._~]+$/)
  codeVerifier!: string;
}

@Controller('spotify')
export class SpotifyController {
  constructor(private readonly spotify: SpotifyService) {}

  @UseGuards(JwtAuthGuard)
  @Post('pkce/sessions')
  createSession(@CurrentUser() user: { id: string }, @Body() dto: CreatePkceSessionDto) {
    return this.spotify.createPkceSession(user.id, dto.codeVerifier);
  }

  @Get('callback')
  async callback(@Query('code') code: string | undefined, @Query('state') state: string | undefined, @Query('error') error: string | undefined, @Res() response: Response) {
    const callbackUrl = await this.spotify.completePkceSession(code, state, error);
    response.redirect(callbackUrl);
  }

  @UseGuards(JwtAuthGuard)
  @Get('pkce/sessions/:state')
  getSession(@CurrentUser() user: { id: string }, @Param('state') state: string) {
    return this.spotify.getPkceSession(user.id, state);
  }
}
