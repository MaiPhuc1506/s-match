-- CreateEnum
CREATE TYPE "RecommendationOutcome" AS ENUM ('SHOWN', 'INVITED', 'ACCEPTED', 'DISMISSED');

-- CreateTable
CREATE TABLE "RecommendationSession" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "criteria" JSONB,
    "totalCandidatesProcessed" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RecommendationSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RecommendationResult" (
    "id" SERIAL NOT NULL,
    "sessionId" INTEGER NOT NULL,
    "recommendedUserId" INTEGER NOT NULL,
    "rank" INTEGER NOT NULL,
    "matchScore" DOUBLE PRECISION NOT NULL,
    "breakdown" JSONB,
    "outcome" "RecommendationOutcome" NOT NULL DEFAULT 'SHOWN',
    "outcomeUpdatedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RecommendationResult_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RecommendationSession_userId_createdAt_idx" ON "RecommendationSession"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "RecommendationResult_sessionId_idx" ON "RecommendationResult"("sessionId");

-- CreateIndex
CREATE INDEX "RecommendationResult_recommendedUserId_idx" ON "RecommendationResult"("recommendedUserId");

-- CreateIndex
CREATE INDEX "RecommendationResult_outcome_idx" ON "RecommendationResult"("outcome");

-- CreateIndex
CREATE UNIQUE INDEX "RecommendationResult_sessionId_recommendedUserId_key" ON "RecommendationResult"("sessionId", "recommendedUserId");

-- AddForeignKey
ALTER TABLE "RecommendationSession" ADD CONSTRAINT "RecommendationSession_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RecommendationResult" ADD CONSTRAINT "RecommendationResult_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "RecommendationSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RecommendationResult" ADD CONSTRAINT "RecommendationResult_recommendedUserId_fkey" FOREIGN KEY ("recommendedUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
