-- Additive: legacy scores and historical ratings are unchanged.
ALTER TABLE "Skill" ADD COLUMN "initialScores" JSONB, ADD COLUMN "initialSource" TEXT, ADD COLUMN "progressHistory" JSONB;
ALTER TABLE "PlayerRating" ADD COLUMN "skillRatings" JSONB;
