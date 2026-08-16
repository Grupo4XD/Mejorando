import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, RoomRole } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma.service';
import { SpotifyService } from '../spotify/spotify.service';
import { RoomsGateway } from './rooms.gateway';

const roomInclude = { members: { orderBy: { joinedAt: 'asc' as const }, select: { displayName: true, role: true, userId: true } }, votes: { select: { userId: true } } } satisfies Prisma.RoomInclude;

@Injectable()
export class RoomsService {
  constructor(private readonly prisma: PrismaService, private readonly spotify: SpotifyService, private readonly gateway: RoomsGateway) {}

  async create(userId: string, displayName: string) {
    await this.spotify.getAccessToken(userId);
    const room = await this.prisma.room.create({
      data: {
        code: await this.newCode(),
        hostId: userId,
        expiresAt: new Date(Date.now() + 4 * 60 * 60 * 1000),
        members: { create: { userId, displayName, role: RoomRole.HOST } }
      },
      include: roomInclude
    });
    return this.present(room);
  }

  async join(userId: string, code: string, displayName: string) {
    const room = await this.openRoomByCode(code);
    try {
      await this.prisma.roomMember.create({ data: { roomId: room.id, userId, displayName, role: RoomRole.GUEST } });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('This name is already used in the room');
      throw error;
    }
    return this.emit(room.id);
  }

  async get(userId: string, code: string) {
    const room = await this.accessibleRoom(userId, code);
    return this.present(room);
  }

  async search(userId: string, code: string, query: string) {
    const room = await this.accessibleRoom(userId, code);
    if (query.trim().length < 2 || query.length > 80) return [];
    return this.spotify.search(room.hostId, query.trim());
  }

  async queue(userId: string, code: string, trackId: string) {
    const room = await this.accessibleRoom(userId, code);
    await this.spotify.addToQueue(room.hostId, trackId);
    return { queued: true };
  }

  async vote(userId: string, code: string) {
    const room = await this.accessibleRoom(userId, code);
    const track = await this.refreshTrack(room);
    if (!track?.id) throw new ConflictException('No active track to vote on');
    let result: { votes: number; shouldSkip: boolean };
    try {
      result = await this.prisma.$transaction(async (tx) => {
        await tx.vote.create({ data: { roomId: room.id, userId, trackId: track.id } });
        const votes = await tx.vote.count({ where: { roomId: room.id, trackId: track.id } });
        const freshRoom = await tx.room.findUniqueOrThrow({ where: { id: room.id } });
        const shouldSkip = votes >= freshRoom.skipThreshold;
        const lock = shouldSkip ? await tx.room.updateMany({ where: { id: room.id, currentTrackId: track.id }, data: { currentTrackId: null, currentTrack: Prisma.JsonNull } }) : { count: 0 };
        return { votes, shouldSkip: lock.count === 1 };
      });
    } catch (error) {
      if ((error as { code?: string }).code === 'P2002') throw new ConflictException('You already voted for this track');
      throw error;
    }
    if (result.shouldSkip) {
      await this.spotify.next(room.hostId);
      await this.prisma.vote.deleteMany({ where: { roomId: room.id } });
    }
    await this.emit(room.id);
    return result;
  }

  async setThreshold(userId: string, code: string, skipThreshold: number) {
    const room = await this.accessibleRoom(userId, code);
    if (room.hostId !== userId) throw new ForbiddenException('Only the host can change the threshold');
    if (skipThreshold > room.members.length) throw new ConflictException('The threshold cannot exceed the number of members');
    await this.prisma.room.update({ where: { id: room.id }, data: { skipThreshold } });
    return this.emit(room.id);
  }

  async refreshCurrentTrack(userId: string, code: string) {
    const room = await this.accessibleRoom(userId, code);
    if (room.hostId !== userId) throw new ForbiddenException('Only the host can refresh playback');
    await this.refreshTrack(room);
    return this.emit(room.id);
  }

  async leave(userId: string, code: string) {
    const room = await this.accessibleRoom(userId, code);
    if (room.hostId === userId) {
      await this.prisma.room.update({ where: { id: room.id }, data: { status: 'CLOSED' } });
    } else {
      await this.prisma.roomMember.delete({ where: { roomId_userId: { roomId: room.id, userId } } });
      await this.prisma.vote.deleteMany({ where: { roomId: room.id, userId } });
    }
    return this.emit(room.id);
  }

  private async refreshTrack(room: { id: string; hostId: string; currentTrackId: string | null }) {
    const track = await this.spotify.currentTrack(room.hostId);
    if (track?.id !== room.currentTrackId) {
      await this.prisma.$transaction([
        this.prisma.room.update({ where: { id: room.id }, data: { currentTrackId: track?.id ?? null, currentTrack: track ?? Prisma.JsonNull } }),
        this.prisma.vote.deleteMany({ where: { roomId: room.id } })
      ]);
    }
    return track;
  }

  private async accessibleRoom(userId: string, code: string) {
    const room = await this.prisma.room.findFirst({ where: { code, status: 'OPEN', expiresAt: { gt: new Date() }, members: { some: { userId } } }, include: roomInclude });
    if (!room) throw new NotFoundException('Room not found or not accessible');
    return room;
  }

  private async openRoomByCode(code: string) {
    const room = await this.prisma.room.findFirst({ where: { code, status: 'OPEN', expiresAt: { gt: new Date() } } });
    if (!room) throw new NotFoundException('Room not found or expired');
    return room;
  }

  private async emit(roomId: string) {
    const room = await this.prisma.room.findUniqueOrThrow({ where: { id: roomId }, include: roomInclude });
    const result = this.present(room);
    this.gateway.emitRoom(roomId, result);
    return result;
  }

  private present(room: Prisma.RoomGetPayload<{ include: typeof roomInclude }>) {
    return {
      code: room.code,
      status: room.status,
      hostId: room.hostId,
      skipThreshold: room.skipThreshold,
      currentTrack: room.currentTrack,
      expiresAt: room.expiresAt.toISOString(),
      members: room.members.map((member) => ({ name: member.displayName, role: member.role })),
      voteCount: room.votes.length
    };
  }

  private async newCode() {
    for (let attempt = 0; attempt < 10; attempt += 1) {
      const code = randomBytes(6).toString('base64url').toUpperCase();
      const found = await this.prisma.room.findUnique({ where: { code }, select: { id: true } });
      if (!found) return code;
    }
    throw new ConflictException('Could not create a unique room code');
  }
}
