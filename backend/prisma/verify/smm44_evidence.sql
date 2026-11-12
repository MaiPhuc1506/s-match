-- SMM-44 — Truy vấn SQL làm bằng chứng cho biên bản kiểm thử (chỉ ĐỌC, không sửa dữ liệu).
-- Chạy:  docker exec -i smatch_postgres_smm44 psql -U postgres -d smatch_clean_verify < backend/prisma/verify/smm44_evidence.sql

\echo '== 1. Migrations đã áp dụng =='
SELECT migration_name, finished_at IS NOT NULL AS finished, rolled_back_at IS NOT NULL AS rolled_back
FROM "_prisma_migrations" ORDER BY migration_name;

\echo '== 2. CHECK / EXCLUDE constraints do SMM-44 và SMM-36 thêm =='
SELECT conrelid::regclass AS "table", conname, contype
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace AND contype IN ('c', 'x')
ORDER BY conrelid::regclass::text, conname;

\echo '== 3. Định nghĩa exclusion constraint chống double-booking =='
SELECT pg_get_constraintdef(oid) AS definition FROM pg_constraint WHERE conname = 'Booking_no_overlap_excl';

\echo '== 4. Số lượng bản ghi seed =='
SELECT 'facilities (named Da Nang)' AS item, count(*) FROM "Facility" WHERE name LIKE '% Badminton'
UNION ALL SELECT 'courts', count(*) FROM "Court"
UNION ALL SELECT 'time slots', count(*) FROM "TimeSlot"
UNION ALL SELECT 'players', count(*) FROM "User" u JOIN "Role" r ON r.id = u."roleId" WHERE r.name = 'PLAYER'
UNION ALL SELECT 'bookings', count(*) FROM "Booking"
UNION ALL SELECT 'matches', count(*) FROM "Match";

\echo '== 5. Tỷ lệ 6-4 giữa hai chủ sân =='
SELECT u.email, count(*) AS facilities
FROM "Facility" f JOIN "User" u ON u.id = f."ownerId"
WHERE f.name LIKE '% Badminton'
GROUP BY u.email ORDER BY u.email;

\echo '== 6. Phải trả về 0 dòng: đơn đang hiệu lực chồng lấn trên cùng một sân =='
SELECT a.id AS booking_a, b.id AS booking_b, a."courtId"
FROM "Booking" a JOIN "Booking" b
  ON a."courtId" = b."courtId" AND a.id < b.id
 AND a.status IN ('PENDING','CONFIRMED') AND b.status IN ('PENDING','CONFIRMED')
 AND a."startTime" < b."endTime" AND a."endTime" > b."startTime";

\echo '== 7. (Chỉ khi có PostGIS) cơ sở trong bán kính 5 km quanh Hai Chau Badminton =='
-- Bỏ qua lỗi nếu server không có PostGIS.
SELECT f.name,
       round(ST_Distance(ST_SetSRID(ST_MakePoint(f.longitude, f.latitude), 4326)::geography,
                         ST_SetSRID(ST_MakePoint(108.2165, 16.061), 4326)::geography)::numeric) AS meters
FROM "Facility" f
WHERE f.latitude IS NOT NULL AND f.longitude IS NOT NULL
  AND ST_DWithin(ST_SetSRID(ST_MakePoint(f.longitude, f.latitude), 4326)::geography,
                 ST_SetSRID(ST_MakePoint(108.2165, 16.061), 4326)::geography, 5000)
ORDER BY meters;
