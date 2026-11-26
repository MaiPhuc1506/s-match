-- Existing and new profiles are private until the player explicitly opts in.
ALTER TABLE "PlayerProfile"
  ADD COLUMN "locationSharingEnabled" BOOLEAN NOT NULL DEFAULT false;
