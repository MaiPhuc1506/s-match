-- SMM-44 — Database integrity hardening (additive migration, no table/column is dropped or renamed).
--
-- 1. Chống double-booking ở tầng DATABASE (không chỉ ở tầng service):
--    EXCLUDE constraint (btree_gist) cấm hai Booking đang hiệu lực (PENDING/CONFIRMED)
--    của cùng một sân có khoảng thời gian [startTime, endTime) chồng lấn nhau.
--    Khoảng nửa mở '[)' => đơn kết thúc 19:00 và đơn bắt đầu 19:00 KHÔNG xung đột.
--    Điều kiện WHERE khớp với BookingsService.create (CONFIRMED + PENDING).
-- 2. CHECK constraint cho các miền giá trị mà DTO/service đã áp dụng (DB là lớp bảo vệ cuối).
--
-- Thứ tự quan trọng: CHECK (startTime < endTime) phải có TRƯỚC exclusion constraint,
-- vì tsrange(lower > upper) sẽ báo lỗi.
--
-- Nếu DB đã có dữ liệu vi phạm, migration sẽ dừng với thông báo rõ ràng (transaction rollback).
-- Chạy prisma/verify trước khi deploy lên DB dùng chung (xem docs/audits/SMM-44-DATABASE-BACKEND-TESTING.md).

-- ---------------------------------------------------------------------------
-- 0. Pre-flight: báo lỗi sớm, dễ hiểu nếu đang có đơn đặt sân chồng lấn
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  overlap_count integer;
BEGIN
  SELECT count(*) INTO overlap_count
  FROM "Booking" a
  JOIN "Booking" b
    ON a."courtId" = b."courtId"
   AND a."id" < b."id"
   AND a."status" IN ('PENDING', 'CONFIRMED')
   AND b."status" IN ('PENDING', 'CONFIRMED')
   AND a."startTime" < b."endTime"
   AND a."endTime" > b."startTime";

  IF overlap_count > 0 THEN
    RAISE EXCEPTION 'SMM-44: % cap Booking dang hieu luc bi chong lan thoi gian tren cung mot san. Huy hoac sua cac don nay truoc khi ap dung migration.', overlap_count;
  END IF;
END
$$;

-- ---------------------------------------------------------------------------
-- 1. Extension (btree_gist là contrib chuẩn của PostgreSQL, có sẵn trong image postgres:16-alpine)
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------------------------------------------------------------------------
-- 2. CHECK constraints
-- ---------------------------------------------------------------------------

-- Booking
ALTER TABLE "Booking"
  ADD CONSTRAINT "Booking_time_order_check" CHECK ("endTime" > "startTime"),
  ADD CONSTRAINT "Booking_totalPrice_check" CHECK ("totalPrice" >= 0);

-- TimeSlot ("HH:MM" zero-padded => so sánh chuỗi tương đương so sánh giờ)
ALTER TABLE "TimeSlot"
  ADD CONSTRAINT "TimeSlot_dayOfWeek_check" CHECK ("dayOfWeek" BETWEEN 0 AND 6),
  ADD CONSTRAINT "TimeSlot_time_order_check" CHECK ("endTime" > "startTime"),
  ADD CONSTRAINT "TimeSlot_price_check" CHECK ("price" >= 0);

-- OperatingHours
ALTER TABLE "OperatingHours"
  ADD CONSTRAINT "OperatingHours_dayOfWeek_check" CHECK ("dayOfWeek" BETWEEN 0 AND 6),
  ADD CONSTRAINT "OperatingHours_time_order_check" CHECK ("closeTime" > "openTime");

-- Availability
ALTER TABLE "Availability"
  ADD CONSTRAINT "Availability_dayOfWeek_check" CHECK ("dayOfWeek" BETWEEN 0 AND 6),
  ADD CONSTRAINT "Availability_time_order_check" CHECK ("endTime" > "startTime");

-- PlayingPreference
ALTER TABLE "PlayingPreference"
  ADD CONSTRAINT "PlayingPreference_skill_range_check"
    CHECK ("minSkillLevel" BETWEEN 1 AND 5 AND "maxSkillLevel" BETWEEN 1 AND 5 AND "minSkillLevel" <= "maxSkillLevel"),
  ADD CONSTRAINT "PlayingPreference_maxDistanceKm_check" CHECK ("maxDistanceKm" >= 0);

-- Toạ độ (NULL được phép)
ALTER TABLE "Facility"
  ADD CONSTRAINT "Facility_latitude_check" CHECK ("latitude" IS NULL OR "latitude" BETWEEN -90 AND 90),
  ADD CONSTRAINT "Facility_longitude_check" CHECK ("longitude" IS NULL OR "longitude" BETWEEN -180 AND 180);

ALTER TABLE "PlayerProfile"
  ADD CONSTRAINT "PlayerProfile_latitude_check" CHECK ("latitude" IS NULL OR "latitude" BETWEEN -90 AND 90),
  ADD CONSTRAINT "PlayerProfile_longitude_check" CHECK ("longitude" IS NULL OR "longitude" BETWEEN -180 AND 180);

-- Match
ALTER TABLE "Match"
  ADD CONSTRAINT "Match_time_order_check" CHECK ("endTime" > "startTime"),
  ADD CONSTRAINT "Match_maxPlayers_check" CHECK ("maxPlayers" >= 2),
  ADD CONSTRAINT "Match_skill_range_check" CHECK ("minSkillLevel" <= "maxSkillLevel");
-- Không thêm CHECK cho feePerPlayer >= 0: CreateMatchDto hiện chưa có @Min(0), thêm CHECK sẽ đổi 201 thành 500.

-- Feedback (bảng PlayerRating đã có CHECK từ migration SMM-36)
ALTER TABLE "Feedback"
  ADD CONSTRAINT "Feedback_rating_check" CHECK ("rating" BETWEEN 1 AND 5),
  ADD CONSTRAINT "Feedback_no_self_feedback_check" CHECK ("senderUserId" <> "recipientUserId");

-- Recommendation
ALTER TABLE "RecommendationResult"
  ADD CONSTRAINT "RecommendationResult_rank_check" CHECK ("rank" >= 1);

-- ---------------------------------------------------------------------------
-- 3. Chống double-booking (EXCLUDE USING gist)
--    "startTime"/"endTime" là TIMESTAMP(3) (không múi giờ) => tsrange là IMMUTABLE, hợp lệ trong constraint.
-- ---------------------------------------------------------------------------
ALTER TABLE "Booking"
  ADD CONSTRAINT "Booking_no_overlap_excl"
  EXCLUDE USING gist (
    "courtId" WITH =,
    tsrange("startTime", "endTime", '[)') WITH &&
  )
  WHERE ("status" IN ('PENDING', 'CONFIRMED'));
