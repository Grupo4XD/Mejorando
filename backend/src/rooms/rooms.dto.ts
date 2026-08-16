import { IsInt, IsString, Length, Matches, Max, Min } from 'class-validator';

export class CreateRoomDto {
  @IsString()
  @Length(2, 32)
  @Matches(/^[\p{L}\p{N} _.-]+$/u)
  displayName!: string;
}

export class JoinRoomDto {
  @IsString()
  @Length(2, 32)
  @Matches(/^[\p{L}\p{N} _.-]+$/u)
  displayName!: string;
}

export class QueueTrackDto {
  @IsString()
  @Matches(/^[A-Za-z0-9]{22}$/)
  trackId!: string;
}

export class SetThresholdDto {
  @IsInt()
  @Min(1)
  @Max(100)
  skipThreshold!: number;
}
