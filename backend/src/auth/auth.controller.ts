import { Body, Controller, Post } from '@nestjs/common';
import { IsUUID } from 'class-validator';
import { AuthService } from './auth.service';

class AnonymousLoginDto {
  @IsUUID()
  deviceId!: string;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('anonymous')
  anonymous(@Body() dto: AnonymousLoginDto) {
    return this.authService.anonymous(dto.deviceId);
  }
}
