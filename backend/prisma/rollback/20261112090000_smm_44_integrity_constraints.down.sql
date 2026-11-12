-- Rollback thủ công cho migration 20261112090000_smm_44_integrity_constraints.
-- Prisma không có "migrate down": chạy file này bằng psql / prisma db execute, sau đó xoá bản ghi
-- tương ứng trong "_prisma_migrations" (hoặc dùng `prisma migrate resolve --rolled-back <tên migration>`).
-- Không động tới dữ liệu; extension btree_gist được giữ lại (vô hại).

ALTER TABLE "Booking" DROP CONSTRAINT IF EXISTS "Booking_no_overlap_excl";

ALTER TABLE "RecommendationResult" DROP CONSTRAINT IF EXISTS "RecommendationResult_rank_check";

ALTER TABLE "Feedback"
  DROP CONSTRAINT IF EXISTS "Feedback_rating_check",
  DROP CONSTRAINT IF EXISTS "Feedback_no_self_feedback_check";

ALTER TABLE "Match"
  DROP CONSTRAINT IF EXISTS "Match_time_order_check",
  DROP CONSTRAINT IF EXISTS "Match_maxPlayers_check",
  DROP CONSTRAINT IF EXISTS "Match_skill_range_check";

ALTER TABLE "PlayerProfile"
  DROP CONSTRAINT IF EXISTS "PlayerProfile_latitude_check",
  DROP CONSTRAINT IF EXISTS "PlayerProfile_longitude_check";

ALTER TABLE "Facility"
  DROP CONSTRAINT IF EXISTS "Facility_latitude_check",
  DROP CONSTRAINT IF EXISTS "Facility_longitude_check";

ALTER TABLE "PlayingPreference"
  DROP CONSTRAINT IF EXISTS "PlayingPreference_skill_range_check",
  DROP CONSTRAINT IF EXISTS "PlayingPreference_maxDistanceKm_check";

ALTER TABLE "Availability"
  DROP CONSTRAINT IF EXISTS "Availability_dayOfWeek_check",
  DROP CONSTRAINT IF EXISTS "Availability_time_order_check";

ALTER TABLE "OperatingHours"
  DROP CONSTRAINT IF EXISTS "OperatingHours_dayOfWeek_check",
  DROP CONSTRAINT IF EXISTS "OperatingHours_time_order_check";

ALTER TABLE "TimeSlot"
  DROP CONSTRAINT IF EXISTS "TimeSlot_dayOfWeek_check",
  DROP CONSTRAINT IF EXISTS "TimeSlot_time_order_check",
  DROP CONSTRAINT IF EXISTS "TimeSlot_price_check";

ALTER TABLE "Booking"
  DROP CONSTRAINT IF EXISTS "Booking_time_order_check",
  DROP CONSTRAINT IF EXISTS "Booking_totalPrice_check";
