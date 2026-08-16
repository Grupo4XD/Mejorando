import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateRoomDto, JoinRoomDto, QueueTrackDto, SetThresholdDto } from './rooms.dto';
import { RoomsService } from './rooms.service';

@UseGuards(JwtAuthGuard)
@Controller('rooms')
export class RoomsController {
  constructor(private readonly rooms: RoomsService) {}

  @Post()
  create(@CurrentUser() user: { id: string }, @Body() dto: CreateRoomDto) {
    return this.rooms.create(user.id, dto.displayName);
  }

  @Post(':code/join')
  join(@CurrentUser() user: { id: string }, @Param('code') code: string, @Body() dto: JoinRoomDto) {
    return this.rooms.join(user.id, code, dto.displayName);
  }

  @Get(':code')
  get(@CurrentUser() user: { id: string }, @Param('code') code: string) {
    return this.rooms.get(user.id, code);
  }

  @Get(':code/search')
  search(@CurrentUser() user: { id: string }, @Param('code') code: string, @Query('q') query: string) {
    return this.rooms.search(user.id, code, query);
  }

  @Post(':code/queue')
  queue(@CurrentUser() user: { id: string }, @Param('code') code: string, @Body() dto: QueueTrackDto) {
    return this.rooms.queue(user.id, code, dto.trackId);
  }

  @Post(':code/votes')
  vote(@CurrentUser() user: { id: string }, @Param('code') code: string) {
    return this.rooms.vote(user.id, code);
  }

  @Post(':code/threshold')
  threshold(@CurrentUser() user: { id: string }, @Param('code') code: string, @Body() dto: SetThresholdDto) {
    return this.rooms.setThreshold(user.id, code, dto.skipThreshold);
  }

  @Post(':code/refresh')
  refresh(@CurrentUser() user: { id: string }, @Param('code') code: string) {
    return this.rooms.refreshCurrentTrack(user.id, code);
  }

  @Post(':code/leave')
  leave(@CurrentUser() user: { id: string }, @Param('code') code: string) {
    return this.rooms.leave(user.id, code);
  }
}
