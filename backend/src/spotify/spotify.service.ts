import { BadGatewayException, BadRequestException, ConflictException, Injectable, NotFoundException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosError } from 'axios';
import { createHash, randomBytes, randomUUID } from 'crypto';
import { PrismaService } from '../prisma.service';
import { TokenCipher } from './token-cipher.service';

type SpotifyTokens = { access_token: string; refresh_token?: string; expires_in: number; scope?: string };

@Injectable()
export class SpotifyService {
  private readonly clientId: string;
  private readonly redirectUri: string;
  private readonly mobileCallbackUri: string;

  constructor(private readonly prisma: PrismaService, private readonly cipher: TokenCipher, config: ConfigService) {
    this.clientId = config.getOrThrow<string>('SPOTIFY_CLIENT_ID');
    this.redirectUri = config.getOrThrow<string>('SPOTIFY_REDIRECT_URI');
    this.mobileCallbackUri = config.getOrThrow<string>('MOBILE_CALLBACK_URI');
  }

  async createPkceSession(userId: string, codeVerifier: string) {
    const state = randomUUID();
    await this.prisma.pkceSession.create({
      data: { state, userId, codeVerifierEnc: this.cipher.encrypt(codeVerifier), expiresAt: new Date(Date.now() + 10 * 60 * 1000) }
    });
    const challenge = createHash('sha256').update(codeVerifier).digest('base64url');
    const params = new URLSearchParams({
      client_id: this.clientId,
      response_type: 'code',
      redirect_uri: this.redirectUri,
      state,
      code_challenge_method: 'S256',
      code_challenge: challenge,
      scope: 'user-read-private user-read-email user-read-playback-state user-read-currently-playing user-modify-playback-state'
    });
    return { state, authorizationUrl: `https://accounts.spotify.com/authorize?${params.toString()}` };
  }

  async completePkceSession(code?: string, state?: string, oauthError?: string) {
    if (!state) throw new BadRequestException('Missing OAuth state');
    const session = await this.prisma.pkceSession.findUnique({ where: { state } });
    if (!session || session.expiresAt < new Date()) throw new NotFoundException('OAuth session expired');
    if (oauthError || !code) return this.mobileRedirect(state, 'error');
    try {
      const tokens = await this.exchangeCode(code, this.cipher.decrypt(session.codeVerifierEnc));
      const profile = await axios.get<{ id: string; product: string }>('https://api.spotify.com/v1/me', { headers: { Authorization: `Bearer ${tokens.access_token}` }, timeout: 10000 });
      if (profile.data.product !== 'premium') throw new ConflictException('Spotify Premium is required to host a room');
      await this.prisma.$transaction([
        this.prisma.user.update({ where: { id: session.userId }, data: { spotifyUserId: profile.data.id } }),
        this.prisma.spotifyConnection.upsert({
          where: { userId: session.userId },
          create: {
            userId: session.userId,
            accessTokenEncrypted: this.cipher.encrypt(tokens.access_token),
            refreshTokenEncrypted: this.cipher.encrypt(tokens.refresh_token ?? ''),
            expiresAt: new Date(Date.now() + tokens.expires_in * 1000),
            scope: tokens.scope ?? ''
          },
          update: {
            accessTokenEncrypted: this.cipher.encrypt(tokens.access_token),
            refreshTokenEncrypted: this.cipher.encrypt(tokens.refresh_token ?? ''),
            expiresAt: new Date(Date.now() + tokens.expires_in * 1000),
            scope: tokens.scope ?? ''
          }
        }),
        this.prisma.pkceSession.update({ where: { id: session.id }, data: { completedAt: new Date() } })
      ]);
      return this.mobileRedirect(state, 'success');
    } catch {
      return this.mobileRedirect(state, 'error');
    }
  }

  async getPkceSession(userId: string, state: string) {
    const session = await this.prisma.pkceSession.findFirst({ where: { state, userId } });
    if (!session) throw new NotFoundException('OAuth session not found');
    return { completed: session.completedAt !== null, success: session.completedAt !== null };
  }

  async getAccessToken(userId: string) {
    const connection = await this.prisma.spotifyConnection.findUnique({ where: { userId } });
    if (!connection) throw new ConflictException('Spotify is not connected');
    if (connection.expiresAt.getTime() > Date.now() + 60000) return this.cipher.decrypt(connection.accessTokenEncrypted);
    const refreshToken = this.cipher.decrypt(connection.refreshTokenEncrypted);
    if (!refreshToken) throw new UnauthorizedException('Spotify connection expired');
    const tokens = await this.refreshToken(refreshToken);
    await this.prisma.spotifyConnection.update({
      where: { userId },
      data: {
        accessTokenEncrypted: this.cipher.encrypt(tokens.access_token),
        refreshTokenEncrypted: tokens.refresh_token ? this.cipher.encrypt(tokens.refresh_token) : connection.refreshTokenEncrypted,
        expiresAt: new Date(Date.now() + tokens.expires_in * 1000),
        scope: tokens.scope ?? connection.scope
      }
    });
    return tokens.access_token;
  }

  async search(userId: string, query: string) {
    const token = await this.getAccessToken(userId);
    const response = await this.spotifyRequest(() => axios.get('https://api.spotify.com/v1/search', { params: { q: query, type: 'track', limit: 10 }, headers: { Authorization: `Bearer ${token}` }, timeout: 10000 }));
    return (response.data.tracks?.items ?? []).map((track: { id: string; name: string; artists: { name: string }[]; album: { images: { url: string }[] } }) => ({ id: track.id, name: track.name, artist: track.artists.map((artist) => artist.name).join(', '), imageUrl: track.album.images[0]?.url ?? null }));
  }

  async addToQueue(userId: string, trackId: string) {
    const token = await this.getAccessToken(userId);
    await this.spotifyRequest(() => axios.post('https://api.spotify.com/v1/me/player/queue', undefined, { params: { uri: `spotify:track:${trackId}` }, headers: { Authorization: `Bearer ${token}` }, timeout: 10000 }));
  }

  async next(userId: string) {
    const token = await this.getAccessToken(userId);
    await this.spotifyRequest(() => axios.post('https://api.spotify.com/v1/me/player/next', undefined, { headers: { Authorization: `Bearer ${token}` }, timeout: 10000 }));
  }

  async currentTrack(userId: string) {
    const token = await this.getAccessToken(userId);
    const response = await this.spotifyRequest(() => axios.get('https://api.spotify.com/v1/me/player/currently-playing', { headers: { Authorization: `Bearer ${token}` }, timeout: 10000 }), true);
    if (response.status === 204 || !response.data?.item) return null;
    const item = response.data.item;
    return { id: item.id as string, name: item.name as string, artist: (item.artists as { name: string }[]).map((artist) => artist.name).join(', '), imageUrl: item.album?.images?.[0]?.url ?? null };
  }

  private async exchangeCode(code: string, codeVerifier: string) {
    const payload = new URLSearchParams({ client_id: this.clientId, grant_type: 'authorization_code', code, redirect_uri: this.redirectUri, code_verifier: codeVerifier });
    const response = await axios.post<SpotifyTokens>('https://accounts.spotify.com/api/token', payload, { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: 10000 });
    return response.data;
  }

  private async refreshToken(refreshToken: string) {
    const payload = new URLSearchParams({ client_id: this.clientId, grant_type: 'refresh_token', refresh_token: refreshToken });
    const response = await axios.post<SpotifyTokens>('https://accounts.spotify.com/api/token', payload, { headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, timeout: 10000 });
    return response.data;
  }

  private async spotifyRequest<T>(request: () => Promise<T>, acceptNoContent = false): Promise<any> {
    try {
      return await request();
    } catch (error) {
      const axiosError = error as AxiosError;
      if (acceptNoContent && axiosError.response?.status === 204) return axiosError.response;
      if (axiosError.response?.status === 401) throw new UnauthorizedException('Spotify authorization failed');
      if (axiosError.response?.status === 429) throw new BadGatewayException('Spotify rate limit reached');
      throw new BadGatewayException('Spotify request failed');
    }
  }

  private mobileRedirect(state: string, result: 'success' | 'error') {
    const url = new URL(this.mobileCallbackUri);
    url.searchParams.set('state', state);
    url.searchParams.set('result', result);
    return url.toString();
  }
}
