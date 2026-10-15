-- SMM-28: lưu vị trí người chơi để phục vụ Geo Search / Matchmaking
ALTER TABLE "PlayerProfile"
  ADD COLUMN "latitude" DOUBLE PRECISION,
  ADD COLUMN "longitude" DOUBLE PRECISION,
  ADD COLUMN "locationUpdatedAt" TIMESTAMP(3);

-- CreateIndex
CREATE INDEX "PlayerProfile_latitude_longitude_idx" ON "PlayerProfile"("latitude", "longitude");
