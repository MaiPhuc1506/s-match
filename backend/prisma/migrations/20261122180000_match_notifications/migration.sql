CREATE TABLE "MatchNotification" (
  "id" SERIAL NOT NULL,
  "userId" INTEGER NOT NULL,
  "matchId" INTEGER NOT NULL,
  "kind" TEXT NOT NULL,
  "isRead" BOOLEAN NOT NULL DEFAULT false,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "MatchNotification_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "MatchNotification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "MatchNotification_userId_createdAt_idx" ON "MatchNotification"("userId", "createdAt");
