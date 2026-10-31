-- Shared raw feedback for SMM-34 / SMM-36; no aggregation or rating history.
CREATE TABLE "Feedback" (
    "id" SERIAL NOT NULL,
    "matchId" INTEGER NOT NULL,
    "senderUserId" INTEGER NOT NULL,
    "recipientUserId" INTEGER NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Feedback_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "Feedback_matchId_senderUserId_recipientUserId_key"
ON "Feedback"("matchId", "senderUserId", "recipientUserId");

CREATE INDEX "Feedback_recipientUserId_createdAt_idx"
ON "Feedback"("recipientUserId", "createdAt");

-- Preserve feedback: deletion of a referenced Match/User must be handled explicitly.
ALTER TABLE "Feedback" ADD CONSTRAINT "Feedback_matchId_fkey"
FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Feedback" ADD CONSTRAINT "Feedback_senderUserId_fkey"
FOREIGN KEY ("senderUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Feedback" ADD CONSTRAINT "Feedback_recipientUserId_fkey"
FOREIGN KEY ("recipientUserId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
