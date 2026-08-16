import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma.service';

@Injectable()
export class AuthService {
  constructor(private readonly prisma: PrismaService, private readonly jwt: JwtService) {}

  async anonymous(deviceId: string) {
    const user = await this.prisma.user.upsert({ where: { deviceId }, update: {}, create: { deviceId } });
    return { accessToken: await this.jwt.signAsync({ sub: user.id }), userId: user.id };
  }
}
