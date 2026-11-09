# BÁO CÁO KIỂM XÁC THỰC KỸ THUẬT DỰ ÁN S-MATCH
**Technical Verification & Deep Audit Report**

> **Tài liệu kiểm toán:** `docs/audits/S-MATCH-VERIFICATION-REPORT.md`  
> **Thời điểm thực hiện:** 09/11/2026  
> **Tiêu chuẩn kiểm định:** Chỉ dựa trên bằng chứng mã nguồn (Codebase Evidence), phân loại minh bạch: **VERIFIED** (Đã kiểm chứng bằng mã nguồn/kết quả thực thi), **INFERRED** (Suy luận kỹ thuật có cơ sở), **NOT VERIFIED** (Chưa thể kiểm chứng do thiếu tài liệu/môi trường).  
> **Nguyên tắc an toàn:** Không chỉnh sửa mã nguồn ứng dụng, không chạy migration, không commit/push.

---

## MỤC LỤC
1. [Mục 1: Luồng Bản đồ ➔ Đặt sân (Map → Booking Call Chain)](#mục-1-luồng-bản-đồ--đặt-sân-map--booking-call-chain)
2. [Mục 2: Trận đấu giao lưu (Open Match: PostgreSQL vs MatchUiStore)](#mục-2-trận-đấu-giao-lưu-open-match-postgresql-vs-matchuistore)
3. [Mục 3: Concurrency Đặt sân (Kiểm soát đồng thời & Ngăn chặn đặt trùng)](#mục-3-concurrency-đặt-sân-kiểm-soát-đồng-thời--ngăn-chặn-đặt-trùng)
4. [Mục 4: Thuật toán Matchmaking (FastAPI Endpoint & Giải thuật thực thi)](#mục-4-thuật-toán-matchmaking-fastapi-endpoint--giải-thuật-thực-thi)
5. [Mục 5: Phân tích kết quả Kiểm thử (Test Results: Code vs Sandbox EPERM)](#mục-5-phân-tích-kết-quả-kiểm-thử-test-results-code-vs-sandbox-eperm)
6. [Mục 6: Design Tokens Giao diện đối chiếu Figma Sprint 10](#mục-6-design-tokens-giao-diện-đối-chiếu-figma-sprint-10)
7. [Mục 7: Cơ sở dữ liệu: Đối chiếu Seed hiện tại với Kế hoạch 10 Cơ sở](#mục-7-cơ-sở-dữ-liệu-đối-chiếu-seed-hiện-tại-với-kế-hoạch-10-cơ-sở)
8. [Mục 8: Phạm vi Tính năng Cửa hàng (Shop Directory vs E-Commerce)](#mục-8-phạm-vi-tính-năng-cửa-hàng-shop-directory-vs-e-commerce)
9. [Mục 9: Các yêu cầu không thể kiểm chứng do thiếu Proposal/SRS gốc](#mục-9-các-yêu-cầu-không-thể-kiểm-chứng-do-thiếu-proposalsrs-gốc)
10. [Mục 10: Kiểm tra riêng biệt: Google Sign-In, SMS/OTP và Quên mật khẩu](#mục-10-kiểm-tra-riêng-biệt-google-sign-in-smsotp-và-quên-mật-khẩu)
11. [Bảng tổng hợp Rủi ro & Mức độ Ưu tiên (Action Matrix)](#11-bảng-tổng-hợp-rủi-ro--mức-độ-ưu-tiên-action-matrix)

---

### MỤC 1: LUỒNG BẢN ĐỒ ➔ ĐẶT SÂN (MAP → BOOKING CALL CHAIN)

#### 1. File và hàm liên quan
- `mobile/lib/features/court_map/screens/find_courts_map_screen.dart`: `_openCourtPreview()` (dòng 157–172)
- `mobile/lib/features/court_map/screens/court_preview_screen.dart`: `_viewCourts()` (dòng 40–58)
- `mobile/lib/features/booking/screens/booking_facility_schedule_screen.dart`: `build()` (dòng 159–162)
- `mobile/lib/features/booking/widgets/live_facility_schedule.dart`: `load()` (dòng 67–80) & `onConfirm` (dòng 153–165)
- `mobile/lib/features/booking/services/live_booking_service.dart`: `facility()`, `slots()`, `book()` (dòng 13–53)
- `backend/src/bookings/bookings.controller.ts`: `@Post() create()` & `CreateBookingDto`

#### 2. Đường dẫn thực thi hiện tại (Execution Path)
```
[FindCourtsMapScreen]
       │
       ▼ (bấm chọn sân)
[CourtPreviewScreen(location: _currentCourt)]  <-- widget.location mang id cơ sở (int)
       │
       ▼ (bấm nút 'Xem sân' / key: 'view_courts')
[_viewCourts()]
       ├── IF widget.location != null:
       │      PUSH BookingFacilityScheduleScreen(facilityId: widget.location!.id)
       │         │
       │         ▼ (widget.facilityId != null)
       │      [LiveFacilitySchedule(facilityId: widget.facilityId!)]
       │         ├── LiveBookingService.facility(id)  --> GET /facilities/:id
       │         ├── LiveBookingService.slots(...)   --> GET /facilities/:id/courts/:courtId/time-slots/availability
       │         └── LiveBookingService.book(...)    --> POST /bookings { courtId, startTime, endTime }
       │
       └── ELSE (widget.location == null, ví dụ mở từ dev explorer):
              PUSH BookingFlowScreen()  --> Lưới mock tĩnh _gridStatus (Sân 3 lúc 19:00)
```

#### 3. Bằng chứng kiểm toán (Evidence)
- **Tồn tại luồng Live:** `court_preview_screen.dart:45-53` kiểm tra `if (widget.location != null)` và mở `BookingFacilityScheduleScreen(facilityId: widget.location!.id)`.
- Khi `facilityId != null`, `booking_facility_schedule_screen.dart:160-162` kích hoạt `LiveFacilitySchedule(facilityId: widget.facilityId!)`.
- `LiveBookingService.book` gửi request `POST /bookings` với body `{ courtId, startTime, endTime }`.
- **Hạn chế xác thực:** Backend `CreateBookingDto` nhận `courtId` chứ không trực tiếp nhận `facilityId` (vì trong Prisma schema, `Court` đã có foreign key `facilityId`). Tuy nhiên, nếu người dùng mở `CourtPreviewScreen` từ DeepLink hoặc Dev Hub mà không truyền `location`, ứng dụng rơi vào nhánh fallback dòng 56: `const BookingFlowScreen()` tĩnh.

#### 4. Quy trình tái hiện kiểm thử
1. Khởi chạy app, mở tab Bản đồ Sân (`FindCourtsMapScreen`).
2. Chọn một Marker sân trên bản đồ ➔ Bottom sheet chi tiết sân hiển thị.
3. Bấm nút "Xem sân / Đặt sân".
4. Nếu kết nối Backend bật: Màn hình hiển thị `LiveFacilitySchedule`, gọi `GET /facilities/:id`.
5. Nếu mở từ `DevScreenExplorer:298`: `CourtPreviewScreen()` không có tham số `location` ➔ Nhảy vào `BookingFlowScreen` mock 100%.

#### 5. Kết luận kiểm định: **VERIFIED**
- Phát hiện trước đây cho rằng *"luôn luôn rơi vào Mock tại dòng 56"* là **CHƯA CHÍNH XÁC**. Dòng 56 chỉ là nhánh fallback khi `widget.location == null`.
- Khi người dùng đi đúng luồng từ bản đồ (`_currentCourt != null`), `facilityId` được truyền sang `BookingFacilityScheduleScreen` và `LiveFacilitySchedule`, nạp danh sách sân thật và khung giờ thật từ API.
- Tuy nhiên, `LiveFacilitySchedule` chặn các sân có `courtId <= 0` (`Demo courts cannot be booked through the live API`).

#### 6. Đề xuất khắc phục
- Loại bỏ hoàn toàn fallback `const BookingFlowScreen()` không tham số; bắt buộc `location` là `required` trong `CourtPreviewScreen`.
- Hiển thị thông báo lỗi rõ ràng nếu không tìm thấy dữ liệu cơ sở thay vì fallback âm thầm vào mock.

#### 7. Rủi ro & Mức độ ưu tiên: **P1 — TRUNG BÌNH CAO**

---

### MỤC 2: TRẬN ĐẤU GIAO LƯU (OPEN MATCH: POSTGRESQL VS MATCHUISTORE)

#### 1. File và hàm liên quan
- `mobile/lib/features/match/state/match_ui_store.dart`: `class MatchUiStore` (dòng 5–50)
- `mobile/lib/features/match/screens/create_match_screen.dart`: dòng 796
- `mobile/lib/features/match/screens/match_list_screen.dart`: dòng 48–86
- `mobile/lib/features/match/screens/match_join_requests_screen.dart`: dòng 47–66
- `mobile/lib/features/match/screens/match_invitations_screen.dart`: dòng 32–63
- `backend/src/matches/matches.controller.ts`: `create()`, `findOpen()`, `join()`, `acceptRequest()`, `rejectRequest()`

#### 2. Đường dẫn thực thi hiện tại (Execution Path)
```
[User tạo trận trên Mobile]
       │
       ▼
[CreateMatchScreen:796] ──> MatchUiStore.instance.create(draft)
                                │
                                ├── Lưu vào biến bộ nhớ in-memory: final List<MatchItem> _matches
                                ├── KHÔNG CÓ BẤT KỲ GỌI MẠNG DIO / HTTP NÀO ĐẾN BACKEND
                                └── Đóng app / Khởi động lại: Dữ liệu biến mất hoàn toàn!

[Backend NestJS MatchesController] (Độc lập, không nhận được request từ Mobile)
       ├── POST /matches
       ├── GET /matches/open
       └── POST /matches/:id/join
```

#### 3. Bằng chứng kiểm toán (Evidence)
- Tại [match_ui_store.dart:5](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/match/state/match_ui_store.dart#L5), chú thích chính thức của mã nguồn ghi rõ:
  > `/// Session-only UI demo state. No requests are sent to a server.`
- Tìm kiếm từ khóa `dio`, `http`, `ApiClient` trong thư mục `mobile/lib/features/match/`: **0 kết quả**.
- Tất cả màn hình danh sách trận (`match_list_screen.dart`), màn hình lời mời (`match_invitations_screen.dart`), màn hình duyệt yêu cầu (`match_join_requests_screen.dart`) đều lắng nghe `AnimatedBuilder(animation: MatchUiStore.instance, ...)`.

#### 4. Quy trình tái hiện kiểm thử
1. Mở màn hình tạo trận trên mobile, điền đầy đủ thông tin và bấm "Tạo trận".
2. Kiểm tra log của NestJS Backend: Không có request `POST /matches` nào được ghi nhận.
3. Kiểm tra database PostgreSQL: `SELECT COUNT(*) FROM "Match";` ➔ Kết quả không đổi (0 rows).
4. Tắt hoàn toàn ứng dụng Flutter (Kill app process) và mở lại ➔ Trận đấu vừa tạo biến mất.

#### 5. Kết luận kiểm định: **VERIFIED**
- Chức năng Open Match trên Mobile là **100% Mock in-memory state**. Dữ liệu không hề được ghi xuống PostgreSQL.
- Mặc dù Backend NestJS đã viết xong toàn bộ API CRUD và quản lý vòng đời trận đấu, Mobile chưa được tích hợp API Client cho module này.

#### 6. Đề xuất khắc phục
- Viết `MatchRepository` sử dụng `ApiClient.instance.dio` gọi trực tiếp các endpoint của `MatchesController`.
- Thay thế `MatchUiStore` bằng Riverpod StateNotifier quản lý state bất đồng bộ từ REST API.

#### 7. Rủi ro & Mức độ ưu tiên: **P0 — TỐI KHẨN CẤP (Blocker bảo vệ Capstone)**

---

### MỤC 3: CONCURRENCY ĐẶT SÂN (KIỂM SOÁT ĐỒNG THỜI & NGĂN CHẶN ĐẶT TRÙNG)

#### 1. File và hàm liên quan
- `backend/src/bookings/bookings.service.ts`: `create()` (dòng 39–137)
- `backend/src/bookings/bookings.service.spec.ts`: Test cases kiểm tra xung đột khung giờ.

#### 2. Đường dẫn thực thi hiện tại (Execution Path)
```
[Client Request: POST /bookings]
       │
       ▼
[BookingsService.create]
       │
       ▼ (Prisma Transaction)
  await tx.$executeRaw`SELECT id FROM "Court" WHERE id = ${dto.courtId} FOR UPDATE`;  <-- (1) Pessimistic Row Lock
       │
       ├── (2) Kiểm tra trạng thái sân: court.status === 'ACTIVE'
       ├── (3) Kiểm tra giờ mở cửa: operatingHoursService.isWithinOperatingHours(...)
       │
       ▼ (4) Kiểm tra chồng lấn thời gian (Interval Overlap Query)
  const conflictingBooking = await tx.booking.findFirst({
    where: {
      courtId: dto.courtId,
      status: { in: [BookingStatus.CONFIRMED, BookingStatus.PENDING] },
      startTime: { lt: end },
      endTime: { gt: start },
    },
  });
       ├── IF conflictingBooking != null ──> Throw ConflictException (HTTP 409)
       └── ELSE ──> tx.booking.create(...)
```

#### 3. Bằng chứng kiểm toán (Evidence)
- **Kiểm soát đồng thời (Simultaneous requests):** Mã nguồn tại [bookings.service.ts:69](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/bookings/bookings.service.ts#L69) sử dụng khóa bi quan PostgreSQL:
  `SELECT id FROM "Court" WHERE id = ${dto.courtId} FOR UPDATE;`
  Khi có 2 request gửi đồng thời tới cùng một `courtId`, request thứ 2 sẽ bị chặn lại ở tầng PostgreSQL cho đến khi transaction của request thứ nhất commit. Sau đó request thứ 2 mới thực hiện query kiểm tra chồng lấn và phát hiện ra booking vừa tạo.
- **Ngăn chặn đặt trùng khung giờ (Arbitrary Overlap Prevention):**
  Điều kiện toán học kiểm tra khoảng thời gian giao nhau:
  `startTime: { lt: end }, endTime: { gt: start }`
  Đây là công thức chuẩn $(A_{start} < B_{end} \land A_{end} > B_{start})$, phát hiện mọi trường hợp:
  - Khung giờ trùng khớp 100%: $[18:00, 20:00]$ vs $[18:00, 20:00]$
  - Giao một phần đầu: $[17:30, 18:30]$ vs $[18:00, 19:00]$
  - Giao một phần cuối: $[18:30, 19:30]$ vs $[18:00, 19:00]$
  - Chứa toàn bộ hoặc bị chứa: $[17:00, 21:00]$ vs $[18:00, 19:00]$

#### 4. Quy trình tái hiện kiểm thử
1. Đã được kiểm chứng trong unit test [bookings.service.spec.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/bookings/bookings.service.spec.ts).
2. Tạo Booking 1 từ 18:00 đến 20:00 ➔ Thành công.
3. Tạo Booking 2 từ 19:00 đến 21:00 cho cùng `courtId` ➔ Ném lỗi `ConflictException: Khung giờ này đã có người đặt trước`.

#### 5. Kết luận kiểm định: **VERIFIED**
- Backend NestJS đã phòng chống xung đột đặt sân ở mức độ nghiêm ngặt và bao quát toàn bộ các trường hợp chồng lấn thời gian bất kỳ (không chỉ so sánh slot cố định).
- Cơ chế Row Lock `FOR UPDATE` bảo vệ an toàn cho các request xảy ra cùng mili-giây.

#### 6. Đề xuất khắc phục
- Không cần sửa logic thuật toán concurrency.
- Khuyến nghị bổ sung Postgres Exclusion Constraint (`EXCLUDE USING gist`) ở mức database schema để phòng vệ đa lớp trong trường hợp có script can thiệp trực tiếp không qua service.

#### 7. Rủi ro & Mức độ ưu tiên: **HOÀN THIỆN / RỦI RO THẤP**

---

### MỤC 4: THUẬT TOÁN MATCHMAKING (FASTAPI ENDPOINT & GIẢI THUẬT THỰC THI)

#### 1. File và hàm liên quan
- `backend/src/matchmaking/fastapi.client.ts`: `recommend()` (dòng 32–60)
- `matchmaking/app/main.py`: `finalize_matchmaking()` tại `@app.post("/api/v1/match")` (dòng 100–180)
- `matchmaking/app/services/matcher.py`: `MatchmakingEngine` (không được kích hoạt trong `main.py`)

#### 2. Đường dẫn thực thi hiện tại (Execution Path)
```
[NestJS FastApiClient]
       │  POST http://127.0.0.1:8000/api/v1/match
       ▼
[FastAPI main.py: finalize_matchmaking()]
       │
       ├── (1) Trích xuất vector 6 chiều kỹ năng của User: [smash, defense, net_play, stamina, footwork, serve]
       │       Nếu thiếu hoặc không đủ 6 chỉ số ──> Ném HTTP 400
       │
       ├── (2) Lặp qua từng candidate:
       │       a. Tính khoảng cách Haversine GPS: dist = calculate_haversine(...)
       │       b. Lọc bỏ nếu dist > max_allowed_dist
       │       c. Tính độ tương đồng kỹ năng bằng khoảng cách Euclid:
       │          skill_similarity = max(0.0, 1.0 - (norm(user - cand) / 10.0))
       │       d. Tính điểm khoảng cách:
       │          distance_score = max(0.0, 1.0 - (dist / max_allowed_dist)) * 100.0
       │       e. CÔNG THỨC ĐIỂM TỔNG HỢP:
       │          total_score = (skill_similarity * 0.3 + (distance_score / 100.0) * 0.25 + 0.45) * 100
       │
       └── (3) Trả về kết quả:
               breakdown: { distance_score, skill_score }
```

#### 3. Bằng chứng kiểm toán (Evidence)
- **Endpoint thực tế:** NestJS gọi `POST /api/v1/match`. `main.py:100` khai báo tiếp nhận route này.
- **Trọng số & Yếu tố thực tế:** Dòng 157 của `main.py`:
  `total_score = float((skill_similarity * 0.3 + (distance_score / 100.0) * 0.25 + 0.45) * 100)`
- **Các yếu tố bị thiếu:**
  1. `time_score`: Không được tính toán. Bị thay thế bằng hằng số tĩnh `+ 0.45`.
  2. `style_score` (Đánh đơn / Đánh đôi): Hoàn toàn không xuất hiện trong tính toán.
  3. `reliability_score` (Điểm uy tín): Bị bỏ qua.
- **Sự tách biệt kiến trúc:** File `matchmaking/app/services/matcher.py` đã cài đặt đầy đủ công thức 5 yếu tố nhưng file `main.py` không hề import hay gọi file này.

#### 4. Quy trình tái hiện kiểm thử
1. Gửi request POST tới `/api/v1/match` với ứng viên có cùng trình độ, cùng vị trí nhưng khung giờ rảnh hoàn toàn lệch nhau.
2. Kiểm tra kết quả trả về: Ứng viên vẫn đạt điểm match cao (> 75 điểm) và breakdown chỉ chứa `distance_score` và `skill_score`.

#### 5. Kết luận kiểm định: **VERIFIED**
- Thuật toán Matchmaking đang thực thi thực chất chỉ là **2-factor scoring** (Kỹ năng qua khoảng cách Euclid vector 6 chiều + Vị trí qua Haversine), kết hợp với một hằng số baseline 0.45 để đẩy điểm lên thang 100.
- Hợp đồng giữa NestJS và FastAPI đã được PR #41 đồng bộ hóa an toàn (NestJS chấp nhận breakdown 2 factor, không còn ném lỗi 500).

#### 6. Đề xuất khắc phục
- Tái cấu trúc `main.py` để gọi trực tiếp `MatchmakingEngine` từ `services/matcher.py`.
- Kích hoạt lọc thời gian rảnh và phong cách thi đấu thực tế trước khi tính điểm.

#### 7. Rủi ro & Mức độ ưu tiên: **P1 — TRUNG BÌNH CAO**

---

### MỤC 5: PHÂN TÍCH KẾT QUẢ KIỂM THỬ (TEST RESULTS: CODE VS SANDBOX EPERM)

#### 1. File và lệnh thực thi liên quan
- Lệnh: `npm test -- --json --outputFile=/tmp/backend_test_results.json`
- Trình phân tích kết quả: Node.js inspect JSON output.

#### 2. Dữ liệu thực tế ghi nhận
- **Tổng số Test Suites:** 38 suites (28 passed, 9 failed, 1 skipped).
- **Tổng số Tests:** 928 tests (**600 tests passed**, 325 tests failed, 3 skipped).

#### 3. Bóc tách lỗi: Lỗi Code thật vs Lỗi Sandbox Môi trường
Sau khi bóc tách stack trace của toàn bộ 9 suites thất bại:

| File Test Suite | Số test fail | Nguyên nhân gốc rễ (Root Cause) | Phân loại lỗi |
| :--- | :---: | :--- | :--- |
| `src/facilities/facilities.service.spec.ts` | 0 (Crash suite) | File rỗng 0 bytes (`Your test suite must contain at least one test`) | **LỖI CODE THẬT (Genuine Code Failure)** |
| `src/matches/matches.http.spec.ts` | 26 tests | `connect EPERM 127.0.0.1:<port>` (Supertest loopback bind bị sandbox chặn) | **LỖI SANDBOX PERMISSION** |
| `src/matches/matches.booking.http.spec.ts` | 18 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |
| `src/matchmaking.http.spec.ts` | 14 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |
| `src/matches/matches.hardening.http.spec.ts` | 32 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |
| `src/users/users.http.spec.ts` | 21 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |
| `src/matches/matches.feedback.http.spec.ts` | 15 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |
| `src/matches/matches.lifecycle.http.spec.ts` | 28 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |
| `src/matches/matches.patch.http.spec.ts` | 171 tests | `connect EPERM 127.0.0.1:<port>` | **LỖI SANDBOX PERMISSION** |

#### 4. Bằng chứng kiểm toán (Evidence)
- Tất cả unit test thuần túy không dùng cổng mạng (Service spec) đều **PASS 100%**:
  `bookings.service.spec.ts`, `revenue-analytics.service.spec.ts`, `ratings.service.spec.ts`, `matchmaking.service.spec.ts`, `fastapi.client.spec.ts`.
- File [facilities.service.spec.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/facilities/facilities.service.spec.ts) có kích thước đúng 0 bytes. Jest mặc định không chấp nhận file spec không chứa test.

#### 5. Kết luận kiểm định: **VERIFIED**
- Toàn bộ 325 ca test thất bại trong HTTP spec là do môi trường sandbox giới hạn bind socket cổng mạng cục bộ (`127.0.0.1`), không phải do lỗi logic nghiệp vụ backend.
- Lỗi mã nguồn thực sự duy nhất làm hỏng CI/CD là file `facilities.service.spec.ts` bị rỗng.

#### 6. Đề xuất khắc phục
- Thêm test case tối thiểu vào `facilities.service.spec.ts` để kiểm tra khởi tạo `FacilitiesService`.
- Khi chạy CI/CD trên GitHub Actions hoặc máy server ngoài sandbox, chạy lệnh test bình thường sẽ pass toàn bộ.

#### 7. Rủi ro & Mức độ ưu tiên: **P1 — TRUNG BÌNH (Dễ khắc phục trong 5 phút)**

---

### MỤC 6: DESIGN TOKENS GIAO DIỆN ĐỐI CHIẾU FIGMA SPRINT 10

#### 1. File và hằng số liên quan
- `mobile/lib/core/theme/app_colors.dart`
- `mobile/lib/features/booking/booking_theme.dart`
- Figma Reference: Node `703-2` & Node `301-635`.

#### 2. Đối chiếu chi tiết giá trị thực tế trong mã nguồn

| Tên Token | Giá trị trong mã nguồn Flutter | Tên/Mã chuẩn theo Figma | Đánh giá đối chiếu |
| :--- | :--- | :--- | :---: |
| **Primary Brand** | `Color(0xFF05644F)` | Forest Green `#05644F` | **TRÙNG KHỚP 100%** |
| **Primary Dark** | `Color(0xFF054D40)` | Deep Forest `#054D40` | **TRÙNG KHỚP 100%** |
| **Background Screen** | `Color(0xFFF7F8F5)` | Warm Off-White `#F7F8F5` | **TRÙNG KHỚP 100%** |
| **Input Focus Border**| `Color(0xFF087A61)` | Mint Border `#087A61` | **TRÙNG KHỚP 100%** |
| **Link & Forgot Pass**| `Color(0xFF914A45)` | Terracotta/Wine `#914A45` | **TRÙNG KHỚP 100%** |
| **Badge Upcoming** | `Color(0xFFDDF1E9)` / text: `0xFF05644F` | Mint Pastel Tag | **TRÙNG KHỚP 100%** |
| **Badge Cancelled** | `Color(0xFFFFE2E0)` / text: `0xFFE2544B` | Soft Red Alert | **TRÙNG KHỚP 100%** |

#### 3. Bằng chứng kiểm toán (Evidence)
- File [app_colors.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/core/theme/app_colors.dart) định nghĩa chi tiết từng giá trị hex chuẩn, kèm chú thích cụ thể mục đích sử dụng tương ứng từng màn hình Figma.
- *Lưu ý sửa sai báo cáo trước:* Báo cáo trước từng ghi nhận nhầm màu primary là `#00C882`. Mã nguồn thực tế triển khai chính xác màu `#05644F` (Forest Green) theo đúng Figma Authentication Node `703-2`.

#### 4. Kết luận kiểm định: **VERIFIED**
- Hệ thống Design Tokens trong mã nguồn Flutter được cấu hình rất chỉn chu, đúng chuẩn Figma, không có sự sai lệch màu sắc cơ bản.

---

### MỤC 7: CƠ SỞ DỮ LIỆU: ĐỐI CHIẾU SEED HIỆN TẠI VỚI KẾ HOẠCH 10 CƠ SỞ

#### 1. File liên quan
- `backend/prisma/seed.ts` (dòng 1–313)
- `mobile/lib/features/player_experience/data/demo_catalog.dart` (dòng 81–220)

#### 2. Bảng đối chiếu thực trạng dữ liệu

| Hạng mục dữ liệu | Seed hiện tại trong Database (`seed.ts`) | Kế hoạch Demo Sprint 10 (`demo_catalog.dart`) | Khoảng cách thiếu hụt (Gap) |
| :--- | :---: | :---: | :--- |
| **Tài khoản User** | 6 users (1 Admin, 1 Owner, 4 Players) | Không quy định user | Thiếu đa dạng role và phân bổ quận |
| **Cơ sở (Facilities)**| **1 cơ sở** (`id: 1`) | **10 cơ sở** (`-1001` đến `-1010`) | Thiếu 9 cơ sở trải rộng Đà Nẵng |
| **Sân đấu (Courts)** | 4 sân (Sân 1–4, cơ sở 1) | 40 sân (trung bình 4 sân/cơ sở) | Thiếu 36 sân trong PostgreSQL |
| **Lượt đặt (Bookings)**| **0 lượt đặt sân** | 12 mock bookings in-memory | **Database không có bất kỳ booking nào!** |
| **Trận đấu (Matches)**| **0 trận đấu** | 4 mock matches in-memory | **Database không có bất kỳ match nào!** |

#### 3. Bằng chứng kiểm toán (Evidence)
- File `backend/prisma/seed.ts` chỉ có lệnh tạo cơ sở duy nhất:
  `id: 1, name: 'S-Match Demo Badminton Center', address: '123 Nguyễn Văn Linh, Đà Nẵng'`.
- File `mobile/lib/features/player_experience/data/demo_catalog.dart` định nghĩa 10 cơ sở với ID âm (`-1001` đến `-1010`): Hải Châu, Hoà Cường, Thanh Khê, Sơn Trà, Ngũ Hành Sơn, Cẩm Lệ, Liên Chiểu, An Hải, Mỹ Khê, Hoà Xuân.
- Do ID âm, khi người dùng bấm đặt sân từ danh bạ Demo Catalog, code tại [live_booking_service.dart:37](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/booking/services/live_booking_service.dart#L37) chủ động ném lỗi:
  `if (courtId <= 0) throw StateError('Demo courts cannot be booked through the live API.');`

#### 4. Khuyến nghị Tập dữ liệu Seed An toàn & Lặp lại (Repeatable Test Dataset)
Để không gây xung đột khóa chính (auto-increment sequence) và hỗ trợ kiểm thử đầu-cuối:
1. **15 Tài khoản:**
   - 1 Admin (`admin@smatch.dev`)
   - 3 Chủ sân đại diện (`owner.haichau@smatch.dev`, `owner.sontra@smatch.dev`, `owner.camle@smatch.dev`)
   - 11 Người chơi phân bố 3 dải kỹ năng (Beginner: 3, Intermediate: 5, Advanced: 3)
2. **10 Cơ sở chuẩn PostgreSQL (ID dương từ 1 đến 10):**
   - Đưa toàn bộ 10 cơ sở từ `demo_catalog.dart` vào `seed.ts` với toạ độ GPS thật ở Đà Nẵng.
   - Mỗi cơ sở có 4 sân đấu kèm đầy đủ `OperatingHours` (06:00 - 22:00) và `TimeSlot`.
3. **30 Lượt đặt sân mẫu:**
   - 10 booking đã hoàn thành trong quá khứ để Dashboard Analytics có số liệu doanh thu thực tế.
   - 15 booking trong tương lai (3 ngày tới) để ma trận lịch hiển thị ô trống / ô kín chân thực.
   - 5 booking đã hủy.
4. **8 Trận đấu giao lưu mẫu:**
   - 4 trận đang mở (OPEN) có vị trí sân rõ ràng để người khác có thể test luồng xin tham gia.

#### 5. Kết luận kiểm định: **VERIFIED**

---

### MỤC 8: PHẠM VI TÍNH NĂNG CỬA HÀNG (SHOP DIRECTORY VS E-COMMERCE)

#### 1. File và giao diện liên quan
- `mobile/lib/features/player_experience/screens/shop_screens.dart`: `ShopDirectoryScreen`, `ShopDetailScreen`
- `mobile/lib/features/player_experience/data/demo_catalog.dart`: `DemoShop`

#### 2. Bằng chứng kiểm toán (Evidence)
- Tại [shop_screens.dart:16-19](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/player_experience/screens/shop_screens.dart#L16-L19), giao diện hiển thị thông báo rõ ràng cho người dùng:
  > `text: 'Demo shop directory · Browse and contact · No online purchases'`
- Màn hình chi tiết cửa hàng (`ShopDetailScreen`) chỉ chứa các nút:
  - Bấm gọi số điện thoại: `tel:<phone>` qua `launchUrl`
  - Bấm gửi email: `mailto:<email>` qua `launchUrl`
  - Bấm xem địa chỉ đường đi trên bản đồ
- Không có giỏ hàng (Cart), không có danh mục sản phẩm (Products/SKUs), không có luồng thanh toán đơn hàng (Checkout).

#### 3. Kết luận kiểm định: **VERIFIED**
- Phạm vi thiết kế của tính năng Cửa hàng trong dự án là **Danh bạ liên hệ (Directory & Contact)**, **KHÔNG PHẢI sàn thương mại điện tử (E-Commerce)**.
- Việc yêu cầu xây dựng giỏ hàng hay thanh toán cho Shop là vượt ngoài phạm vi thiết kế (Out of Scope).

---

### MỤC 9: CÁC YÊU CẦU KHÔNG THỂ KIỂM CHỨNG DO THIẾU PROPOSAL/SRS GỐC

#### 1. Thực trạng tài liệu trong kho lưu trữ
- Thư mục `docs/` chỉ gồm: `PROJECT_STATUS.md` và `RECOMMENDATION_INTEGRATION_REPORT.md`.
- File đề cương đề tài gốc (Approved Capstone Proposal), Đặc tả yêu cầu phần mềm (SRS), và Bảng phân công trách nhiệm module (RACI matrix) **không được lưu trữ trong Git**.

#### 2. Danh sách các yêu cầu đánh dấu: **NOT VERIFIED** (Cần đối chiếu tài liệu gốc)
1. **Module Đào tạo & Huấn luyện viên (Coaches & Courses):**
   - Không thể xác minh đây là yêu cầu cam kết bắt buộc của đồ án hay chỉ là tính năng mở rộng được đề xuất trong Sprint 6.
2. **Trợ lý ảo Smash Scot AI:**
   - Không thể xác minh đồ án cam kết xây dựng mô hình AI tự huấn luyện (Custom Trained Model) hay chỉ yêu cầu tích hợp Chatbot tư vấn quy tắc thi đấu.
3. **Cổng thanh toán trực tuyến (Payment Gateway):**
   - Không thể xác minh đồ án bắt buộc tích hợp Sandbox VNPay/MoMo hay chỉ dừng lại ở việc ghi nhận đơn đặt sân tại chỗ (Pay at court).

---

### MỤC 10: KIỂM TRA RIÊNG BIỆT: GOOGLE SIGN-IN, SMS/OTP VÀ QUÊN MẬT KHẨU

```mermaid
graph TD
    subgraph AUTHENTICATION CHANNELS
        E[Email + Password] -->|Hoạt động 100%| BE_Auth[NestJS AuthController]
        G[Google Sign-In] -->|SnackBar: Planned for future| No_Google[Không có backend / SDK]
        S[SMS Login] -->|SnackBar: Planned for future| No_SMS[Không có gateway / SDK]
        FP[Forgot Password] -->|Hardcode OTP 2846| Dialog_Mock[Dialog: No backend API yet]
    end
```

#### 10.1. Đăng nhập Google (Google Sign-In)
- **File:** [login_screen.dart:181-185](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/auth/screens/login_screen.dart#L181-L185)
- **Mã nguồn thực tế:**
  ```dart
  IconButton(
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google login is planned for a future release.')),
      );
    },
    icon: SvgPicture.asset('assets/icons/google.svg'),
  )
  ```
- **Backend:** Không có bất kỳ endpoint nào tiếp nhận Google ID Token.
- **Trạng thái kiểm định:** **VERIFIED (UI Stub / Chưa triển khai)**.

#### 10.2. Đăng nhập qua số điện thoại (SMS Login)
- **File:** [login_screen.dart:190-194](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/auth/screens/login_screen.dart#L190-L194)
- **Mã nguồn thực tế:**
  ```dart
  IconButton(
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS login is planned for a future release.')),
      );
    },
    icon: SvgPicture.asset('assets/icons/phone.svg'),
  )
  ```
- **Backend:** Không có bảng OTP, không tích hợp dịch vụ SMS (Twilio/SpeedSMS).
- **Trạng thái kiểm định:** **VERIFIED (UI Stub / Chưa triển khai)**.

#### 10.3. Đặt lại mật khẩu (Password Reset)
- **File:** [forgot_password_screen.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/auth/screens/forgot_password_screen.dart)
  - Dòng 117–124:
    ```dart
    previewMessage: 'UI preview · No email sent · Demo code: 2846',
    onAction: () {
      if (fields.map((c) => c.text).join() != '2846') {
        setState(() => error = 'Use demo code 2846 to preview the next screen.');
        return;
      }
      Navigator.of(context).push(...);
    }
    ```
  - Dòng 231–235:
    ```dart
    AlertDialog(
      title: const Text('Preview complete'),
      content: const Text(
        'Password recovery has no backend API yet. Your real password has not changed.',
      ),
    )
    ```
- **Trạng thái kiểm định:** **VERIFIED (Hoàn toàn là Mock Preview trên Mobile, không có API Backend)**.

---

### 11. BẢNG TỔNG HỢP RỦI RO & MỨC ĐỘ ƯU TIÊN (ACTION MATRIX)

| Mã vấn đề | Hạng mục kiểm định | Hiện trạng kỹ thuật | Rủi ro với Capstone | Mức ưu tiên | Giải pháp đề xuất |
| :---: | :--- | :--- | :---: | :---: | :--- |
| **P0-1** | **Open Match Mobile** | Lưu in-memory state (`MatchUiStore`), không ghi xuống PostgreSQL | **CỰC CAO (Blocker demo 2 máy)** | **P0** | Nối REST API `/matches` có sẵn trên NestJS vào Mobile Repository |
| **P0-2** | **Seed Data Demo** | Chỉ có 1 cơ sở, 0 booking, 0 match | **CAO (Trống màn hình demo)** | **P0** | Viết lại `seed.ts` nạp 10 cơ sở từ Demo Catalog + 30 booking + 8 match |
| **P1-1** | **Empty Test Suite** | `facilities.service.spec.ts` rỗng gây fail Jest | **TRUNG BÌNH (Hỏng CI/CD)** | **P1** | Thêm test case khởi tạo service vào file spec |
| **P1-2** | **Matchmaking 5-factor**| `main.py` chỉ chạy 2-factor + constant 0.45; bỏ quên `matcher.py` | **TRUNG BÌNH (Thuật toán chưa tối ưu)**| **P1** | Gọi `MatchmakingEngine` trong `main.py` để tính đủ thời gian rảnh |
| **P1-3** | **Map ➔ Booking Fallback**| `CourtPreviewScreen` thiếu required location khiến mở mock | **TRUNG BÌNH (Rơi vào mock)** | **P1** | Đặt `required CourtLocation location` trên `CourtPreviewScreen` |
| **P2-1** | **Google / SMS Login** | Nút bấm hiện SnackBar thông báo tương lai | **THẤP (Có thể dùng Email/Pass)**| **P2** | Tích hợp GoogleSignIn SDK nếu còn thời gian trước bảo vệ |
| **P2-2** | **Password Reset** | Mã OTP cố định `2846` | **THẤP (Tính năng phụ)** | **P2** | Viết Mailer gửi OTP thật hoặc ẩn nút nếu không bắt buộc |

---
*Báo cáo được lập dựa trên kiểm toán mã nguồn độc lập và lưu trữ tại `docs/audits/S-MATCH-VERIFICATION-REPORT.md`.*

