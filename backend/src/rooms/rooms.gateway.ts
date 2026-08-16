import { UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConnectedSocket, MessageBody, OnGatewayConnection, SubscribeMessage, WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { PrismaService } from '../prisma.service';

@WebSocketGateway({ namespace: '/rooms', cors: { origin: process.env.ALLOWED_ORIGINS?.split(',') ?? false } })
export class RoomsGateway implements OnGatewayConnection {
  @WebSocketServer()
  server!: Server;

  constructor(private readonly jwt: JwtService, private readonly prisma: PrismaService) {}

  handleConnection(client: Socket) {
    try {
      const token = client.handshake.auth.token as string | undefined;
      const payload = this.jwt.verify<{ sub: string }>(token ?? '');
      client.data.userId = payload.sub;
    } catch {
      client.disconnect(true);
    }
  }

  @SubscribeMessage('room:subscribe')
  async subscribe(@ConnectedSocket() client: Socket, @MessageBody() data: { code?: string }) {
    if (!data.code || !client.data.userId) return { ok: false };
    const member = await this.prisma.roomMember.findFirst({ where: { userId: client.data.userId, room: { code: data.code, status: 'OPEN', expiresAt: { gt: new Date() } } }, select: { roomId: true } });
    if (!member) return { ok: false };
    await client.join(this.channel(member.roomId));
    return { ok: true };
  }

  emitRoom(roomId: string, room: unknown) {
    this.server.to(this.channel(roomId)).emit('room:updated', room);
  }

  private channel(roomId: string) {
    return `room:${roomId}`;
  }
}
