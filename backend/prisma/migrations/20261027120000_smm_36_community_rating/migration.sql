-- CreateTable
CREATE TABLE "PlayerRating" (
    "id" SERIAL NOT NULL,
    "matchId" INTEGER NOT NULL,
    "raterId" INTEGER NOT NULL,
    "ratedUserId" INTEGER NOT NULL,
    "score" INTEGER NOT NULL,
    "punctuality" INTEGER,
    "sportsmanship" INTEGER,
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PlayerRating_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "PlayerRating_score_check" CHECK ("score" BETWEEN 1 AND 5),
    CONSTRAINT "PlayerRating_punctuality_check" CHECK ("punctuality" IS NULL OR "punctuality" BETWEEN 1 AND 5),
    CONSTRAINT "PlayerRating_sportsmanship_check" CHECK ("sportsmanship" IS NULL OR "sportsmanship" BETWEEN 1 AND 5),
    CONSTRAINT "PlayerRating_no_self_rating_check" CHECK ("raterId" <> "ratedUserId")
);

-- CreateIndex
CREATE INDEX "PlayerRating_ratedUserId_createdAt_idx" ON "PlayerRating"("ratedUserId", "createdAt");

-- CreateIndex
CREATE INDEX "PlayerRating_raterId_createdAt_idx" ON "PlayerRating"("raterId", "createdAt");

-- CreateIndex
CREATE INDEX "PlayerRating_matchId_idx" ON "PlayerRating"("matchId");

-- CreateIndex
CREATE UNIQUE INDEX "PlayerRating_matchId_raterId_ratedUserId_key" ON "PlayerRating"("matchId", "raterId", "ratedUserId");

-- AddForeignKey
ALTER TABLE "PlayerRating" ADD CONSTRAINT "PlayerRating_matchId_fkey" FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlayerRating" ADD CONSTRAINT "PlayerRating_raterId_fkey" FOREIGN KEY ("raterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlayerRating" ADD CONSTRAINT "PlayerRating_ratedUserId_fkey" FOREIGN KEY ("ratedUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
