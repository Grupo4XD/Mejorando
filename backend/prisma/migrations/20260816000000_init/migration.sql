CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE TYPE "RoomRole" AS ENUM ('HOST', 'GUEST');
CREATE TYPE "RoomStatus" AS ENUM ('OPEN', 'CLOSED', 'EXPIRED');

CREATE TABLE "User" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "deviceId" TEXT NOT NULL,
  "spotifyUserId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "SpotifyConnection" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "userId" TEXT NOT NULL,
  "accessTokenEncrypted" TEXT NOT NULL,
  "refreshTokenEncrypted" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "scope" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "SpotifyConnection_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PkceSession" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "state" TEXT NOT NULL,
  "codeVerifierEnc" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "completedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "PkceSession_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "Room" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "code" TEXT NOT NULL,
  "hostId" TEXT NOT NULL,
  "status" "RoomStatus" NOT NULL DEFAULT 'OPEN',
  "skipThreshold" INTEGER NOT NULL DEFAULT 1,
  "currentTrackId" TEXT,
  "currentTrack" JSONB,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Room_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "RoomMember" (
  "roomId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "displayName" TEXT NOT NULL,
  "role" "RoomRole" NOT NULL,
  "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "RoomMember_pkey" PRIMARY KEY ("roomId", "userId")
);

CREATE TABLE "Vote" (
  "roomId" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "trackId" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "Vote_pkey" PRIMARY KEY ("roomId", "userId")
);

CREATE UNIQUE INDEX "User_deviceId_key" ON "User"("deviceId");
CREATE UNIQUE INDEX "User_spotifyUserId_key" ON "User"("spotifyUserId");
CREATE UNIQUE INDEX "SpotifyConnection_userId_key" ON "SpotifyConnection"("userId");
CREATE UNIQUE INDEX "PkceSession_state_key" ON "PkceSession"("state");
CREATE UNIQUE INDEX "Room_code_key" ON "Room"("code");
CREATE INDEX "Room_hostId_idx" ON "Room"("hostId");
CREATE INDEX "Room_expiresAt_idx" ON "Room"("expiresAt");
CREATE UNIQUE INDEX "RoomMember_roomId_displayName_key" ON "RoomMember"("roomId", "displayName");
CREATE INDEX "Vote_roomId_trackId_idx" ON "Vote"("roomId", "trackId");

ALTER TABLE "SpotifyConnection" ADD CONSTRAINT "SpotifyConnection_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "PkceSession" ADD CONSTRAINT "PkceSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Room" ADD CONSTRAINT "Room_hostId_fkey" FOREIGN KEY ("hostId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoomMember" ADD CONSTRAINT "RoomMember_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "RoomMember" ADD CONSTRAINT "RoomMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Vote" ADD CONSTRAINT "Vote_roomId_fkey" FOREIGN KEY ("roomId") REFERENCES "Room"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "Vote" ADD CONSTRAINT "Vote_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
