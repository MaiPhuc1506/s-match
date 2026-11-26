CREATE TABLE "PasswordRecovery" (
  "userId" INTEGER NOT NULL,
  "codeHash" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "lastSentAt" TIMESTAMP(3) NOT NULL,
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "resetTokenHash" TEXT,
  "resetExpiresAt" TIMESTAMP(3),
  CONSTRAINT "PasswordRecovery_pkey" PRIMARY KEY ("userId"),
  CONSTRAINT "PasswordRecovery_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
