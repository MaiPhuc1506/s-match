-- CreateEnum
CREATE TYPE "OpenMatchStatus" AS ENUM ('OPEN', 'FULL', 'CLOSED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ParticipantStatus" AS ENUM ('PENDING', 'ACCEPTED', 'REJECTED', 'LEFT');

-- CreateTable
CREATE TABLE "OpenMatch" (
    "id" SERIAL NOT NULL,
    "bookingId" INTEGER NOT NULL,
    "mode" "MatchMode" NOT NULL DEFAULT 'DOUBLES',
    "purpose" "MatchPurpose" NOT NULL DEFAULT 'CASUAL',
    "neededPlayers" INTEGER NOT NULL,
    "minSkillLevel" INTEGER NOT NULL DEFAULT 1,
    "maxSkillLevel" INTEGER NOT NULL DEFAULT 5,
    "estimatedCostPerPerson" DOUBLE PRECISION,
    "status" "OpenMatchStatus" NOT NULL DEFAULT 'OPEN',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OpenMatch_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MatchParticipant" (
    "id" SERIAL NOT NULL,
    "openMatchId" INTEGER NOT NULL,
    "userId" INTEGER NOT NULL,
    "status" "ParticipantStatus" NOT NULL DEFAULT 'PENDING',
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MatchParticipant_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "OpenMatch_bookingId_key" ON "OpenMatch"("bookingId");

-- CreateIndex
CREATE INDEX "OpenMatch_status_idx" ON "OpenMatch"("status");

-- CreateIndex
CREATE INDEX "MatchParticipant_openMatchId_idx" ON "MatchParticipant"("openMatchId");

-- CreateIndex
CREATE UNIQUE INDEX "MatchParticipant_openMatchId_userId_key" ON "MatchParticipant"("openMatchId", "userId");

-- AddForeignKey
ALTER TABLE "OpenMatch" ADD CONSTRAINT "OpenMatch_bookingId_fkey" FOREIGN KEY ("bookingId") REFERENCES "Booking"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MatchParticipant" ADD CONSTRAINT "MatchParticipant_openMatchId_fkey" FOREIGN KEY ("openMatchId") REFERENCES "OpenMatch"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MatchParticipant" ADD CONSTRAINT "MatchParticipant_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
