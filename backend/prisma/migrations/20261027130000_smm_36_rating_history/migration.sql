-- CreateTable
CREATE TABLE "RatingHistory" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "ratingId" INTEGER,
    "communityRating" DOUBLE PRECISION NOT NULL,
    "ratingCount" INTEGER NOT NULL,
    "reliabilityScore" DOUBLE PRECISION NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RatingHistory_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RatingHistory_userId_createdAt_idx" ON "RatingHistory"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "RatingHistory_ratingId_idx" ON "RatingHistory"("ratingId");

-- AddForeignKey
ALTER TABLE "RatingHistory" ADD CONSTRAINT "RatingHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RatingHistory" ADD CONSTRAINT "RatingHistory_ratingId_fkey" FOREIGN KEY ("ratingId") REFERENCES "PlayerRating"("id") ON DELETE SET NULL ON UPDATE CASCADE;
