# S-MATCH — FINAL SPRINT COMPLETION SCORECARD (AUDIT V2 — RECONCILED)

**Ngày kiểm toán & chuẩn hóa:** 2026-11-09  
**Nhánh Git kiểm tra:** `feature/SMM-41-FinalIntegrationTestingRelease`  
**Chế độ kiểm toán:** STRICT READ-ONLY AUDIT MODE (Độc lập, dựa trên bằng chứng, không sửa mã nguồn/DB)  
**Tài liệu đối chiếu gốc:** [FINAL-SPRINT-REQUIREMENT-MATRIX.md](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/docs/audits/FINAL-SPRINT-REQUIREMENT-MATRIX.md)

---

## 1. Phương Pháp Tính Điểm & Quy Tắc Toán Học (Methodology)

Báo cáo này bác bỏ các con số ước lượng cảm tính từ các lần đánh giá trước (`84.5% UI`, `56% Backend`, `54% DB`, `47.5% E2E`) và tính toán lại từ **60 Yêu cầu nguyên tử (Atomic Requirements)** trải rộng trên **12 Module (`M01`–`M12`)** và **6 Chiều đánh giá (`A`–`F`)** trong [FINAL-SPRINT-REQUIREMENT-MATRIX.md](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/docs/audits/FINAL-SPRINT-REQUIREMENT-MATRIX.md).

### 1.1. Thang điểm từng ô (Cell Rubric) & Phân biệt E2E
Mỗi yêu cầu nguyên tử $i \in \{1..60\}$ được chấm trên 6 chiều $d \in \{A, B, C, D, E, F\}$:
- **`PASS = 1.0`**: Đã triển khai hoàn chỉnh, khớp hợp đồng dữ liệu và có bằng chứng xác thực.
- **`PARTIAL = 0.5`**: Đã triển khai một phần, còn thiếu nhánh xử lý, thiếu trường dữ liệu hoặc còn dùng mock/preview ở một số luồng phụ.
  - **Đặc biệt tại Chiều F (Real E2E Verification):** Báo cáo phân biệt rõ hai cấp độ kiểm chứng E2E:
    1. **`F = 0.5` (API / Database E2E Verified — Simulator E2E Pending):** Luồng nghiệp vụ đã được kiểm chứng đầu-cuối giữa **REST API (NestJS) ↔ PostgreSQL thật** (ví dụ thông qua `bookings.integration.live.spec.ts`), nhưng chưa chạy phiên kiểm thử tương tác trực tiếp trên **Flutter iOS Simulator / Android Emulator** nối toàn bộ dịch vụ thật.
    2. **`F = 1.0` (Full Invariant / End-to-End Verified):** Đã kiểm chứng toàn diện cả bất biến cấp Server/Database (như khóa đồng thời `SELECT ... FOR UPDATE`, tính tiền theo `TimeSlot`, cô lập chế độ Demo/Live, tách biệt `Skill` vs `PlayerRating`).
- **`FAIL / NOT IMPLEMENTED = 0.0`**: Chưa triển khai, chỉ là UI tĩnh/mock khi yêu cầu đòi hỏi tích hợp thật, hoặc lỗi logic.
- **`NV = NOT VERIFIED`**: Không thể xác minh trực tiếp trong chế độ Read-Only (cần chạy migration đang chờ trên DB dùng chung, cần môi trường Docker/venv có `numpy` cho FastAPI, hoặc cần thiết bị thật).
  - Trong **Tỷ lệ hoàn thành đã xác minh (Verified Completion Rate)**: ô `NV` được **loại khỏi mẫu số đã xác minh** ($N_{\text{verified}}$).
  - Trong **Cận dưới bảo thủ (Conservative Lower Bound)**: ô `NV` được tính bằng **`0.0` điểm** trên tổng mẫu số áp dụng ($N_{\text{applicable}}$).
- **`N/A = NOT APPLICABLE`**: Không áp dụng cho yêu cầu đó (ví dụ: chiều UI cho tác vụ migration DB, hoặc chiều DB cho kiểm tra mã màu Figma). Ô `N/A` được loại khỏi mọi mẫu số.

### 1.2. Trọng số cố định trước khi chấm (Upfront Requirement Weights — Reconciled)
Mỗi yêu cầu nguyên tử được gán trọng số cố định $w_i \in \{1, 2, 3\}$ khớp chính xác 100% với cột **Ưu tiên & Trọng số** trong [FINAL-SPRINT-REQUIREMENT-MATRIX.md](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/docs/audits/FINAL-SPRINT-REQUIREMENT-MATRIX.md):
- **$w_i = 3$ (P0 Critical Core — 17 yêu cầu, $\sum w_i = 51$):**
  - `M01` (3): `REQ-AUTH-01`, `REQ-AUTH-02`, `REQ-AUTH-03`
  - `M03` (4): `REQ-FAC-01`, `REQ-FAC-02`, `REQ-FAC-04`, `REQ-FAC-05`
  - `M04` (3): `REQ-BOOK-01`, `REQ-BOOK-02`, `REQ-BOOK-03`
  - `M06` (3): `REQ-MATCH-01`, `REQ-MATCH-02`, `REQ-MATCH-03`
  - `M07` (3): `REQ-MM-01`, `REQ-MM-02`, `REQ-MM-03`
  - `M12` (1): `REQ-OPS-02`
- **$w_i = 2$ (P1 Standard Functional — 37 yêu cầu, $\sum w_i = 74$):**
  - `M01` (1): `REQ-AUTH-04` (Google Sign-In)
  - `M02` (5): `REQ-PROF-01`..`05`
  - `M03` (1): `REQ-FAC-03`
  - `M04` (3): `REQ-BOOK-04`..`06`
  - `M05` (5): `REQ-MAP-01`..`05`
  - `M06` (3): `REQ-MATCH-04`..`06`
  - `M07` (2): `REQ-MM-04`..`05`
  - `M08` (4): `REQ-RATE-01`..`04`
  - `M09` (6): `REQ-FIN-01`..`06`
  - `M11` (4): `REQ-AI-01`..`04`
  - `M12` (3): `REQ-OPS-01`, `REQ-OPS-03`, `REQ-OPS-04`
- **$w_i = 1$ (P2 Secondary / Directory / Optional — 6 yêu cầu, $\sum w_i = 6$):**
  - `M01` (2): `REQ-AUTH-05` (SMS OTP), `REQ-AUTH-06` (Email OTP Password Recovery)
  - `M10` (4): `REQ-CAT-01`..`04` (Courses, Coaches, Shop Directory, Experience Search)
- **Tổng kiểm tra (Reconciliation Check):** $17 + 37 + 6 = \mathbf{60\text{ yêu cầu}}$; Tổng trọng số $\sum_{i=1}^{60} w_i = 51 + 74 + 6 = \mathbf{131}$.

### 1.3. Công thức tổng hợp
1. **Verified Completion Rate (Không trọng số):** $\text{Verified Rate} = \frac{\sum s_{i,d}}{N_{\text{verified}}}$
2. **Evidence Coverage Rate (Độ phủ bằng chứng):** $\text{Coverage Rate} = \frac{N_{\text{verified}}}{N_{\text{applicable}}}$
3. **Conservative Lower Bound (Cận dưới bảo thủ — coi mọi `NV = 0`):** $\text{Conservative Lower Bound} = \frac{\sum s_{i,d}}{N_{\text{applicable}}}$
4. **Weighted Verified Completion Rate & Weighted Lower Bound:** Nhân điểm và mẫu số của từng yêu cầu $i$ với trọng số $w_i$ ($\sum w_i = 131$).

---

## 2. Tổng Hợp Điểm Toàn Dự Án Theo 6 Chiều (Per-Dimension Scorecard)

| Chiều đánh giá (Dimension) | Điểm đạt được ($\sum s$) | Mẫu số đã xác minh ($N_{\text{verified}}$) | Tổng mẫu số áp dụng ($N_{\text{applicable}}$) | Số ô `NV` | Số ô `N/A` | Tỷ lệ hoàn thành đã xác minh (Verified %) | Độ phủ bằng chứng (Coverage %) | Cận dưới bảo thủ (Conservative %) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **A. UI Implementation** | `46.0` | `56` | `56` | `0` | `4` | **82.14%** | **100.00%** | **82.14%** |
| **B. Business Logic** | `43.5` | `60` | `60` | `0` | `0` | **72.50%** | **100.00%** | **72.50%** |
| **C. Backend / API Integration** | `32.5` | `58` | `58` | `0` | `2` | **56.03%** | **100.00%** | **56.03%** |
| **D. Database Persistence & Schema** | `40.5` | `55` | `55` | `0` | `5` | **73.64%** | **100.00%** | **73.64%** |
| **E. Automated Verification (Tests)** | `48.5` | `60` | `60` | `0` | `0` | **80.83%** | **100.00%** | **80.83%** |
| **F. Real E2E Verification** | `12.0` | `43` | `60` | `17` | `0` | **27.91%** | **71.67%** | **20.00%** |
| **TỔNG CỘNG (UNWEIGHTED)** | **`223.0`** | **`332`** | **`349`** | **`17`** | **`11`** | **67.17%** | **95.13%** | **63.90%** |
| **TỔNG CỘNG (WEIGHTED $\sum w_i = 131$)** | **`510.0`** | **`725.0`** | **`761.0`** | **`36.0`** | **`25.0`** | **70.34%** | **95.27%** | **67.02%** |

---

## 3. Bảng Điểm Chi Tiết Theo 12 Module (Per-Module Scorecard)

### 3.1. Bảng điểm Không trọng số (Unweighted Module Breakdown)

| Mã Module | Tên Module & Dải mã Yêu cầu | Số Req | $\sum w_i$ | Điểm đạt ($\sum s$) | Mẫu số xác minh ($N_{\text{ver}}$) | Mẫu số áp dụng ($N_{\text{app}}$) | Số ô `NV` | Verified Rate (%) | Coverage Rate (%) | Conservative Lower Bound (%) |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **M01** | Authentication, Session & RBAC (`REQ-AUTH-01..06`) | 6 | 13 | `19.0` | `35` | `36` | 1 | **54.29%** | 97.22% | **52.78%** |
| **M02** | Player Profile, Match Prefs & 6-Axis Skill Radar (`REQ-PROF-01..05`) | 5 | 10 | `18.5` | `27` | `30` | 3 | **68.52%** | 90.00% | **61.67%** |
| **M03** | Facility CRUD, Courts, Operating Hours & Pricing (`REQ-FAC-01..05`) | 5 | 14 | `23.5` | `30` | `30` | 0 | **78.33%** | 100.00% | **78.33%** |
| **M04** | Court Booking, Concurrency & History (`REQ-BOOK-01..06`) | 6 | 15 | `33.5` | `36` | `36` | 0 | **93.06%** | 100.00% | **93.06%** |
| **M05** | MapLibre Exploration & Nearby Player Discovery (`REQ-MAP-01..05`) | 5 | 10 | `21.5` | `25` | `29` | 4 | **86.00%** | 86.21% | **74.14%** |
| **M06** | Open Match Creation, Join Requests & Invitations (`REQ-MATCH-01..06`) | 6 | 15 | `23.5` | `35` | `36` | 1 | **67.14%** | 97.22% | **65.28%** |
| **M07** | Matchmaking Engine & Recommendations (`REQ-MM-01..05`) | 5 | 13 | `19.0` | `25` | `28` | 3 | **76.00%** | 89.29% | **67.86%** |
| **M08** | Post-Match Feedback & Community Ratings (`REQ-RATE-01..04`) | 4 | 8 | `19.5` | `21` | `24` | 3 | **92.86%** | 87.50% | **81.25%** |
| **M09** | Owner Dashboard, Booking Feed & Finance (`REQ-FIN-01..06`) | 6 | 12 | `16.0` | `36` | `36` | 0 | **44.44%** | 100.00% | **44.44%** |
| **M10** | Coach, Courses & Shop Directory (`REQ-CAT-01..04`) | 4 | 4 | `11.0` | `24` | `24` | 0 | **45.83%** | 100.00% | **45.83%** |
| **M11** | Smash Scot AI & Role-Aware Data Tools (`REQ-AI-01..04`) | 4 | 8 | `4.5` | `21` | `21` | 0 | **21.43%** | 100.00% | **21.43%** |
| **M12** | UI/UX Tokens, DB Migrations, Security & QA (`REQ-OPS-01..04`) | 4 | 9 | `13.5` | `17` | `19` | 2 | **79.41%** | 89.47% | **71.05%** |
| **TỔNG** | **Toàn bộ 12 Module (60 Requirements)** | **60** | **131** | **`223.0`** | **`332`** | **`349`** | **17** | **67.17%** | **95.13%** | **63.90%** |

### 3.2. Bảng điểm Có trọng số (Weighted Module Breakdown)

| Mã Module | Tên Module & Dải mã Yêu cầu | Trọng số ($\sum w_i$) | Điểm có trọng số ($\sum w_i s_{i,d}$) | Mẫu số xác minh có trọng số | Mẫu số áp dụng có trọng số | Weighted Verified Rate (%) | Weighted Coverage (%) | Weighted Lower Bound (%) |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **M01** | Authentication, Session & RBAC (`REQ-AUTH-01..06`) | 13 | `51.5` | `75.0` | `78.0` | **68.67%** | 96.15% | **66.03%** |
| **M02** | Player Profile, Match Prefs & 6-Axis Skill Radar (`REQ-PROF-01..05`) | 10 | `37.0` | `54.0` | `60.0` | **68.52%** | 90.00% | **61.67%** |
| **M03** | Facility CRUD, Courts, Operating Hours & Pricing (`REQ-FAC-01..05`) | 14 | `65.0` | `84.0` | `84.0` | **77.38%** | 100.00% | **77.38%** |
| **M04** | Court Booking, Concurrency & History (`REQ-BOOK-01..06`) | 15 | `84.5` | `90.0` | `90.0` | **93.89%** | 100.00% | **93.89%** |
| **M05** | MapLibre Exploration & Nearby Player Discovery (`REQ-MAP-01..05`) | 10 | `43.0` | `50.0` | `58.0` | **86.00%** | 86.21% | **74.14%** |
| **M06** | Open Match Creation, Join Requests & Invitations (`REQ-MATCH-01..06`) | 15 | `59.0` | `88.0` | `90.0` | **67.05%** | 97.78% | **65.56%** |
| **M07** | Matchmaking Engine & Recommendations (`REQ-MM-01..05`) | 13 | `49.5` | `66.0` | `73.0` | **75.00%** | 90.41% | **67.81%** |
| **M08** | Post-Match Feedback & Community Ratings (`REQ-RATE-01..04`) | 8 | `39.0` | `42.0` | `48.0` | **92.86%** | 87.50% | **81.25%** |
| **M09** | Owner Dashboard, Booking Feed & Finance (`REQ-FIN-01..06`) | 12 | `32.0` | `72.0` | `72.0` | **44.44%** | 100.00% | **44.44%** |
| **M10** | Coach, Courses & Shop Directory (`REQ-CAT-01..04`) | 4 | `11.0` | `24.0` | `24.0` | **45.83%** | 100.00% | **45.83%** |
| **M11** | Smash Scot AI & Role-Aware Data Tools (`REQ-AI-01..04`) | 8 | `9.0` | `42.0` | `42.0` | **21.43%** | 100.00% | **21.43%** |
| **M12** | UI/UX Tokens, DB Migrations, Security & QA (`REQ-OPS-01..04`) | 9 | `29.5` | `38.0` | `42.0` | **77.63%** | 90.48% | **70.24%** |
| **TỔNG** | **Toàn bộ 12 Module (Có trọng số)** | **131** | **`510.0`** | **`725.0`** | **`761.0`** | **70.34%** | **95.27%** | **67.02%** |

---

## 4. Phân Tách Điểm Theo Phạm Vi Dự Án (Scope-Separated Scorecards — Reconciled)

Ba nhóm phạm vi dưới đây khớp chính xác tuyệt đối với phân loại tại Mục 3 của [FINAL-SPRINT-REQUIREMENT-MATRIX.md](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/docs/audits/FINAL-SPRINT-REQUIREMENT-MATRIX.md) ($49 + 9 + 2 = 60\text{ yêu cầu}$; $\sum w = 114 + 15 + 2 = 131$):

1. **Tier 1 — Core Sprint Scope (Sprints 1–9 + P0.1 — 49 yêu cầu, $\sum w = 114$):**
   - Bao gồm: `REQ-AUTH-01..04` (4), `REQ-PROF-01..05` (5), `REQ-FAC-01..04` (4), `REQ-BOOK-01..06` (6), `REQ-MAP-01..05` (5), `REQ-MATCH-01..06` (6), `REQ-MM-01..05` (5), `REQ-RATE-01..04` (4), `REQ-FIN-01..06` (6), `REQ-OPS-01..04` (4).
2. **Tier 2 — Sprint 10 Approved Enhancements (9 yêu cầu, $\sum w = 15$):**
   - Bao gồm: `REQ-FAC-05` (10 cơ sở Đà Nẵng, $w=3$), `M10` `REQ-CAT-01..04` (Khóa học, HLV, Danh bạ Cửa hàng, Tìm kiếm Home, $\sum w=4$), và `M11` `REQ-AI-01..04` (Smash Scot AI & Role-Aware Tools, $\sum w=8$).
3. **Tier 3 — Optional / Unconfirmed Scope (2 yêu cầu, $\sum w = 2$):**
   - Bao gồm: `REQ-AUTH-05` (SMS OTP, $w=1$) và `REQ-AUTH-06` (Khôi phục mật khẩu Email OTP, $w=1$).

| Nhóm phạm vi (Scope Tier) | Số Req | Tổng trọng số ($\sum w$) | Unweighted Achieved / Verified / Applicable | Unweighted Verified (%) | Unweighted Coverage (%) | Unweighted Conservative (%) | Weighted Achieved / Verified / Applicable | Weighted Verified (%) | Weighted Coverage (%) | Weighted Conservative (%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Core Sprint Scope (Sprints 1–9 + P0.1)** | **49** | **114** | `203.5 / 269 / 286` | **75.65%** | 94.06% | **71.15%** | `483.0 / 629.0 / 665.0` | **76.79%** | 94.59% | **72.63%** |
| **2. Sprint 10 Approved Enhancements (`REQ-FAC-05`, `M10`, `M11`)** | **9** | **15** | `17.0 / 51 / 51` | **33.33%** | 100.00% | **33.33%** | `24.5 / 84.0 / 84.0` | **29.17%** | 100.00% | **29.17%** |
| **3. Optional / Unconfirmed Scope (`REQ-AUTH-05..06`)** | **2** | **2** | `2.5 / 12 / 12` | **20.83%** | 100.00% | **20.83%** | `2.5 / 12.0 / 12.0` | **20.83%** | 100.00% | **20.83%** |
| **TỔNG CỘNG TOÀN DỰ ÁN** | **60** | **131** | **`223.0 / 332 / 349`** | **67.17%** | **95.13%** | **63.90%** | **`510.0 / 725.0 / 761.0`** | **70.34%** | **95.27%** | **67.02%** |

---

## 5. Ma Trận Xác Minh End-to-End Thực Tế & Phân Công Trách Nhiệm E2E (Real E2E Verification Matrix)

### 5.1. Phân bổ Trách nhiệm Xác minh E2E cho cả 4 Thành viên (Distributed E2E Ownership)
Trách nhiệm kiểm chứng E2E được phân bổ đồng đều cho cả 4 thành viên theo đúng phạm vi kiến trúc:
- **Member 1 (Mobile Lead):** Điều phối và trực tiếp thực thi **Real Flutter Simulator E2E** trên iOS Simulator / Android Emulator cho toàn bộ 7 luồng (`E2E-FLOW-A..G`).
- **Member 2 (Database Lead):** Xác minh **Database Persistence, Transaction Isolation (`SELECT ... FOR UPDATE`), 6–4 Owner Data Isolation và Migration Integrity** trên PostgreSQL thật.
- **Member 3 (Backend Lead):** Xác minh **REST API Contracts, JWT/RBAC Guards, Bảo mật vị trí (`GET /candidates/nearby`), Trạng thái thanh toán (`PaymentStatus`) và Cô lập RBAC của AI Tools** qua bộ test HTTP/DB E2E.
- **Member 4 (Matchmaking Lead):** Xác minh **Độ chính xác xếp hạng 5 yếu tố (`MatchmakingEngine`), Tie-breaking tất định, Làm mượt Bayesian (`reliability_score`) và luồng NestJS ↔ FastAPI (`POST /api/v1/match`)**.

### 5.2. Bảng đối chiếu API / Database E2E vs. Flutter Simulator E2E

| Mã luồng (Test ID) | Tên luồng nghiệp vụ & Requirement IDs | Điều kiện tiên quyết (Preconditions) | Tài khoản & Dữ liệu kiểm thử (Tại Đà Nẵng) | Các bước thực thi (Steps) | Kết quả API / Database E2E *(BE + DB + MM)* | Kết quả Flutter Simulator E2E *(Mobile Lead điều phối)* | Bằng chứng (Evidence) | Trạng thái tổng hợp (Status) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **E2E-FLOW-A** | **Map → Facility → Court Detail → Select Slot → Create Booking → Persist in PostgreSQL**<br>(`REQ-BOOK-01..03`, `REQ-FAC-04`) | Docker Postgres (`:5433`) + NestJS (`:3000`) chạy; đã có cơ sở sân tại Đà Nẵng và các sân con. | `player@smatch.dev`, cơ sở Đà Nẵng (`GET /facilities`), slot `18:00-20:00`. | 1. Mở `FindCourtsMapScreen`, tải `GET /facilities`.<br>2. Chọn cơ sở → `CourtPreviewScreen` → `BookingFacilityScheduleScreen`.<br>3. Chọn khung giờ → gửi `POST /bookings`. | **`PASS` (100%):** Lưu `Booking` vào PostgreSQL với `status=CONFIRMED`; 2 request đồng thời dùng khóa `SELECT ... FOR UPDATE` trên bảng `Court` (1 nhận `201`, 1 nhận `409 Conflict`). | **`PARTIAL`:** Đã pass 56/56 Flutter integration/widget tests (`booking_map_integration_test.dart`, `live_booking_test.dart`); chờ chạy phiên tương tác trực tiếp trên Simulator (`TASK-M1-09`). | [P0.1-BOOKING-INTEGRATION.md](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/docs/audits/P0.1-BOOKING-INTEGRATION.md), [bookings.integration.live.spec.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/bookings/bookings.integration.live.spec.ts) | **`PARTIAL` (`API/DB PASS`, `Sim Pending`)** |
| **E2E-FLOW-B** | **Player Booking → Visible in Player History AND Owner Dashboard / Schedule**<br>(`REQ-BOOK-04..05`, `REQ-FIN-02..03`) | Có `Booking` thật trên cơ sở Đà Nẵng thuộc `owner@smatch.dev`. | Player: `player@smatch.dev`<br>Owner: `owner@smatch.dev`. | 1. Player mở `BookingHistoryScreen` (`GET /bookings/my`).<br>2. Owner mở `DashboardScreen` (`GET /bookings/owner`).<br>3. Owner mở tab Schedule.<br>4. Player bấm hủy đơn trên `BookingDetailScreen`. | **`PASS`:** `GET /bookings/my`, `GET /bookings/owner`, và `PATCH /bookings/:id/cancel` đều hoạt động chuẩn xác trên PostgreSQL thật. | **`PARTIAL`:** History & Owner Recent Activity hiển thị đúng. **Thiếu:** (1) Tab Schedule của Owner ở chế độ Live chỉ render thẻ dọc `_bookingCard(b)`, chưa render lưới 2D `DashboardScheduleGrid`; (2) Nút Cancel trên `BookingDetailScreen` chưa gọi `PATCH /bookings/:id/cancel`. | [dashboard_repository.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/dashboard/data/dashboard_repository.dart#L474-L562), [dashboard_screen.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/dashboard/screens/dashboard_screen.dart#L1383-L1400), [booking_detail_screen.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/booking/screens/booking_detail_screen.dart#L204-L221) | **`PARTIAL`** |
| **E2E-FLOW-C** | **Host Creates Open Match → Stored in DB → Visible to Other Users**<br>(`REQ-MATCH-01..02`) | Player có `Booking` hợp lệ tại Đà Nẵng. | Host: `player@smatch.dev`<br>Viewer: `player2@smatch.dev`. | 1. Mở `CreateMatchScreen`, điền thông tin và tạo trận.<br>2. Tài khoản thứ 2 mở `MatchListScreen` xem danh sách kèo mở. | **`PASS` (Backend Code):** `POST /matches`, `POST /bookings/:bookingId/open-match`, `GET /matches/open` đã hoàn thiện kèm khóa transaction. | **`FAIL` (Mobile Mock):** `CreateMatchScreen:796` và `MatchListScreen` chỉ đọc/ghi vào `MatchUiStore.instance` trong RAM, không gọi REST API. | [create_match_screen.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/match/screens/create_match_screen.dart#L790-L805), [matches.controller.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/matches/matches.controller.ts#L39-L58) | **`FAIL`** |
| **E2E-FLOW-D** | **Join Requests & Direct Player Invitations (Find Players Map & Recommendations)**<br>(`REQ-MATCH-03..05`) | Có Open/Private Match; Player 2 xin vào hoặc Host mời từ `FindPlayersMapScreen` / `RecommendationListScreen`. | Host: `player@smatch.dev`<br>Candidate: `player2@smatch.dev`. | 1. Player 2 gửi Join Request; Host duyệt/từ chối trên `MatchJoinRequestsScreen`.<br>2. Host mở `FindPlayersMapScreen` hoặc `RecommendationListScreen` → `RecommendedPlayerDetailScreen` bấm Invite.<br>3. Player 2 mở `MatchInvitationsScreen` bấm Accept/Reject. | **`PARTIAL` (Backend):** Có đủ `POST /matches/:id/join-request`, `PATCH /matches/:id/requests/:userId/approve\|reject`, `POST /matches/:id/invite`, `PATCH /matches/:id/invitations/accept\|reject`, nhưng **thiếu `GET /matches/my-invitations`** để lấy danh sách lời mời. | **`FAIL` (Mobile):** `MatchJoinRequestsScreen` và `MatchInvitationsScreen` dùng `MatchUiStore`; `RecommendedPlayerDetailScreen:15-42` hiện thông báo chưa hỗ trợ mời trực tiếp người chơi. | [recommended_player_detail_screen.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/recommendation/screens/recommended_player_detail_screen.dart#L15-L42), [find_players_map_screen.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/court_map/screens/find_players_map_screen.dart#L144-L171) | **`FAIL`** |
| **E2E-FLOW-E** | **Matchmaking Recommendation → NestJS (`POST /matchmaking/recommend`) → FastAPI (`POST /api/v1/match`)**<br>(`REQ-MM-01..05`) | Postgres (`:5433`), NestJS (`:3000`), FastAPI (`:8000`) chạy; ứng viên quanh Đà Nẵng (`16.0544, 108.2022`). | Requester: `player@smatch.dev` (`lat=16.0471, lon=108.2062`, 6 trục `Skill`). | 1. Mobile gọi `POST /matchmaking/recommend` qua `ApiRecommendationRepository`.<br>2. NestJS `CandidatesService` lấy ứng viên + 6 trục `Skill` + `Availability` + `reliabilityScore` gửi tới FastAPI `POST /api/v1/match`. | **`PARTIAL` (2-Factor vs 5-Factor):** Hợp đồng HTTP chạy thông suốt, nhưng `matchmaking/app/main.py:100-180` bỏ qua `MatchmakingEngine` (5 yếu tố trong `matcher.py`) và chỉ tính 2 yếu tố (`skill * 0.3 + distance * 0.25 + 0.45`). | **`BLOCKED`:** Môi trường `.venv` máy host thiếu `numpy` và chế độ Read-Only không cho phép cài đặt/khởi chạy lại container FastAPI. | [main.py](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/matchmaking/app/main.py#L100-L180), [matcher.py](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/matchmaking/app/services/matcher.py#L29-L187), [fastapi.client.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/matchmaking/fastapi.client.ts#L10-L104) | **`BLOCKED` / `PARTIAL`** |
| **E2E-FLOW-F** | **Match Completion → Post-Match Feedback & Community Rating → Stored & Reflected in Profile**<br>(`REQ-MATCH-06`, `REQ-RATE-01..04`) | Trận đấu kết thúc (`endTime` đã qua); các thành viên `ACCEPTED` đánh giá nhau. | Rater: `player@smatch.dev`<br>Ratee: `player2@smatch.dev`. | 1. Mở `LiveMatchFeedbackScreen` gọi `PATCH /matches/:id/complete`.<br>2. Gửi đánh giá qua `POST /ratings` (`RatingApi`).<br>3. Xem `PlayerProfileScreen` & `RatingHistoryScreen` (`GET /ratings/users/:id/summary`). | **`BLOCKED` (Pending DB Migrations):** Code Backend (`RatingsController`, `RatingsService`) và Mobile (`ApiFeedbackRepository`, `RatingApi`) **đã nối thật 100%**, nhưng 3 bản migration `20261027*` chưa được apply lên Docker PostgreSQL. | **`BLOCKED`:** Chờ apply migration an toàn và nối xong `E2E-FLOW-C/D` để tạo trận thật từ Mobile. | [feedback_repository.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/feedback/data/feedback_repository.dart#L261-L363), [ratings.service.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/ratings/ratings.service.ts) | **`BLOCKED`** |
| **E2E-FLOW-G** | **Owner Analytics & Pay-at-Court Revenue Confirmation**<br>(`REQ-FIN-01`, `REQ-FIN-04..06`) | Có dữ liệu `Booking` thật trên cơ sở của `owner@smatch.dev`. | Owner: `owner@smatch.dev`. | 1. Mở `DashboardScreen` kiểm tra 6 API `/analytics/*`.<br>2. Xác nhận thu tiền tại sân (`PaymentStatus = PAID`) và kiểm tra `collectedRevenue` vs `grossBookedRevenue`. | **`PARTIAL`:** 6 endpoint `/analytics/*` trả về đúng `grossBookedRevenue`, `occupancyRate`, `trend` từ PostgreSQL thật (đã pass `bookings.integration.live.spec.ts`). **Tuy nhiên**, chưa có `PaymentStatus` và API xác nhận thu tiền (`REQ-FIN-04..05`), nên `collectedRevenue` đang trả về `null`. | **`PARTIAL`:** Dashboard hiển thị số liệu `grossBookedRevenue` thật; chưa có luồng bấm xác nhận thu tiền tại sân trên Mobile. | [revenue-analytics.service.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/src/analytics/revenue-analytics.service.ts#L85-L95), [dashboard_repository.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/dashboard/data/dashboard_repository.dart#L595-L608) | **`PARTIAL`** |

---

## 6. Đánh Giá Cơ Sở Dữ Liệu, Chính Sách Kỹ Năng vs. Uy Tín & Quy Trình An Toàn Migration

### 6.1. Quy trình An toàn Bắt buộc trước khi áp dụng 4 bản Migration đang chờ (`REQ-OPS-02`)
Kiểm tra `npx prisma migrate status` xác nhận còn **4 bản migration chưa được áp dụng** trên PostgreSQL Docker (`20261027120000_add_match_feedback`, `20261027120000_smm_36_community_rating`, `20261027130000_smm_36_rating_history`, `20261101120000_smm_40_analytics_indexes`), đồng thời lịch sử migration cũ (`20261006024604` vs `20261014065156`) từng có lệnh `DROP TABLE "TimeSlot"` trước khi tạo lại.

> [!CAUTION]
> **Nguyên tắc An toàn Cơ sở dữ liệu (Mandatory Migration Safety Protocol):**  
> Tuyệt đối **KHÔNG** chạy `prisma migrate deploy` hoặc `prisma db push` trực tiếp lên cơ sở dữ liệu dùng chung khi chưa thực hiện đủ 3 bước được phê duyệt:
> 1. **Sao lưu (Approved Backup):** Chạy `pg_dump` lưu bản chụp toàn bộ schema và dữ liệu hiện hành ra file `.sql` có gắn timestamp.
> 2. **Kiểm chứng cô lập (Isolated Verification):** Dựng một database tạm (staging/throwaway DB), chạy tuần tự toàn bộ 15 migrations từ đầu và kiểm tra trên bản sao dữ liệu hiện tại để xác nhận bảng `TimeSlot` và dữ liệu `Booking` không bị mất.
> 3. **Kế hoạch khôi phục (Rollback Plan):** Chuẩn bị sẵn script SQL hoàn tác (down-migration) cho 4 migration mới và lệnh `psql < backup.sql` để khôi phục tức thì nếu xảy ra lỗi.

### 6.2. Đối chiếu Địa lý Đà Nẵng (Da Nang Seed Plan: 10 Facilities, 2–4 Courts/Facility = 20–40 Courts Total, Stable Keys)
Kiểm tra [demo_catalog.dart](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/mobile/lib/features/player_experience/data/demo_catalog.dart#L23-L184) và [seed.ts](file:///Users/mbp/Documents/WORKSPACE/Capstone/s-match/backend/prisma/seed.ts#L115-L226) xác nhận toàn bộ thiết kế Figma Sprint 10 và dữ liệu gốc của dự án đều đặt tại **TP. Đà Nẵng (Da Nang, Vietnam)** (tọa độ tâm `16.0544, 108.2022`):

| Hạng mục dữ liệu | Kế hoạch chuẩn được phê duyệt (Đà Nẵng) | Hiện trạng trong `backend/prisma/seed.ts` | Hiện trạng trong `mobile/.../demo_catalog.dart` | Giải pháp chuẩn hóa |
| :--- | :--- | :--- | :--- | :--- |
| **Chủ sân (Owners)** | **2 Chủ sân** (`owner@smatch.dev` / `owner1@smatch.dev` và `owner2@smatch.dev`) quản lý theo tỷ lệ **6–4** để kiểm chứng cô lập dữ liệu. | **1 Chủ sân** (`owner@smatch.dev`). | Không gắn Owner ID. | Mở rộng `seed.ts` thêm Owner thứ 2 và gán 6 cơ sở cho Owner 1, 4 cơ sở cho Owner 2. |
| **10 Cơ sở Cầu lông tại Đà Nẵng (Facilities)** | **10 Cơ sở tại Đà Nẵng:**<br>1. Hải Châu (`16.061, 108.2165`)<br>2. Hòa Cường (`16.034, 108.215`)<br>3. Thanh Khê (`16.064, 108.185`)<br>4. An Khê (`16.045, 108.178`)<br>5. An Hải (`16.065, 108.241`)<br>6. Sơn Trà (`16.093, 108.246`)<br>7. Ngũ Hành Sơn (`16.012, 108.258`)<br>8. Hòa Xuân (`15.999, 108.220`)<br>9. Cẩm Lệ (`16.012, 108.192`)<br>10. Hòa Khánh (`16.073, 108.152`) | **Chỉ có 1 Cơ sở** (`S-Match Demo Badminton Center`, `123 Nguyễn Văn Linh, Đà Nẵng`, đang gán cứng `id: 1`). | Có đủ 10 cơ sở Đà Nẵng nhưng mang **ID âm (`-1001`..`-1010`)** và cờ `demo: true`. | Seed đủ 10 cơ sở Đà Nẵng bằng **khóa định danh tự nhiên ổn định (stable unique seed keys, ví dụ tra cứu/upsert theo `name` + `address`)** thay vì giả định cứng ID `1..10`; Mobile đọc động `facility.id` dương thực tế từ `GET /facilities`. |
| **Số lượng sân con (Courts)** | **2–4 sân con / cơ sở (Tổng cộng 20–40 Courts)** kèm `OperatingHours` và `TimeSlot`. | **4 Courts** (thuộc 1 cơ sở duy nhất). | 3–6 sân ảo/cơ sở (`courtId` âm). | Seed **2–4 sân con cho mỗi cơ sở (tổng 20–40 sân)** bằng khóa tự nhiên `(facilityId, name)` kèm `TimeSlot`. |
| **Người chơi (Players) & Kỹ năng 6 trục** | **20+ Players** quanh Đà Nẵng kèm 6 chỉ số `Skill` (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve`) và `Availability`. | **4 Players** (`player@smatch.dev`, `player2..4@smatch.dev`). | Danh sách tĩnh. | Mở rộng lên 20+ Players tại các quận Đà Nẵng (upsert theo `email` duy nhất) để thuật toán Matchmaking 5 yếu tố có tập ứng viên phong phú. |

### 6.3. Chính sách Tách biệt Kỹ năng Tự đánh giá, Radar 6 trục và Điểm Uy tín Sau trận (`REQ-PROF-03..04`, `REQ-RATE-01..04`)
1. **Kỹ năng Kỹ thuật Tự đánh giá ban đầu (`Initial / Retake Self-Assessed Skill` — `REQ-PROF-04`):**
   - Người chơi tự đánh giá (hoặc đánh giá lại) 6 chỉ số kỹ thuật trên `SkillAssessmentScreen`, lưu vào bảng `Skill` (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve` trên thang `0.0–5.0`) qua endpoint `PUT /players/profile/me/skill`.
2. **Biểu đồ Radar Kỹ năng 6 trục (`Six-Axis Skill Radar` — `REQ-PROF-03`):**
   - Widget `ProfileSkillRadar` chỉ đọc và vẽ trực quan 6 trục kỹ thuật hiện tại từ bảng `Skill` (`GET /players/profile/me`).
3. **Điểm Uy tín Cộng đồng Sau trận (`Post-Match Reliability Rating` — `REQ-RATE-01..04`):**
   - Sau khi trận đấu `COMPLETED`, người chơi cùng trận đánh giá nhau qua `POST /ratings` (`score` 1–5, `punctuality`, `sportsmanship`, `comment`), lưu vào `PlayerRating` và `RatingHistory` để tính `communityRating` và `reliabilityScore` (làm mượt Bayesian với `PRIOR_WEIGHT = 3`, `PRIOR_SCORE = 5.0`).
4. **Quy tắc Bất biến về Thay đổi Kỹ năng sau trận:**
   - **Đánh giá sau trận (`POST /ratings` / `POST /matches/:id/feedback`) TUYỆT ĐỐI KHÔNG tự động làm tăng hay làm thay đổi bất kỳ trục nào trong bảng `Skill`.** Điểm kỹ thuật 6 trục chỉ thay đổi khi người chơi chủ động thực hiện lại bài đánh giá trên `SkillAssessmentScreen` (`PUT /players/profile/me/skill`), trong khi đánh giá sau trận chỉ tác động vào `reliabilityScore` (1 trong 5 yếu tố độc lập của `MatchmakingEngine`).

### 6.4. Quyết định Triển khai cho Coach/Courses & Shop Directory (`M10`: `REQ-CAT-01..04`)
- **Phạm vi bất biến của Shop (`REQ-CAT-03`):** Shop bắt buộc giữ nguyên là **Danh bạ tra cứu (`Directory-only`)** (hiển thị tên, quận tại Đà Nẵng, chuyên môn, số điện thoại, email, mở bản đồ/gọi điện ngoài qua `url_launcher`) — **không bao giờ có giỏ hàng, đặt hàng hay thanh toán**.
- **Hai phương án triển khai được định nghĩa đầy đủ trong Backlog:**
  - **Phương án A (Tích hợp PostgreSQL & REST API thật — Chuỗi phụ thuộc `TASK-M2-06` $\rightarrow$ `TASK-M3-07` $\rightarrow$ `TASK-M1-08`):** Tạo bảng chỉ đọc `Course`, `Coach`, `ShopDirectoryEntry` trong Prisma + seed dữ liệu Đà Nẵng (`TASK-M2-06`), cung cấp `GET /catalog/courses`, `GET /catalog/coaches`, `GET /catalog/shops` (`TASK-M3-07`), và nối UI Mobile đọc từ API (`TASK-M1-08`).
  - **Phương án B (Giữ Danh mục Cục bộ `DemoCatalog` — Khuyến nghị nếu ưu tiên P0/P1):** Giữ Khóa học, HLV và Danh bạ Cửa hàng đọc từ `DemoCatalog` trong ứng dụng (đã có đủ dữ liệu Đà Nẵng và pass widget test), trong khi phần tìm kiếm Sân trên `PlayerHomeScreen` / `ExperienceSearchScreen` vẫn bắt buộc nối vào `GET /facilities` thật (`TASK-M1-02`).

---

## 7. Năm Điểm Nghẽn Vận Hành Lớn Nhất Đã Được Xác Minh (Top 5 Operational Blockers)

1. **[Blocker #1 — P0] Đứt gãy tích hợp Open Match & Lời mời Người chơi trên Mobile (`REQ-MATCH-01..05`):**
   - Toàn bộ màn hình Match trên Mobile (`CreateMatchScreen`, `MatchListScreen`, `MatchDetailOpenScreen`, `MatchJoinRequestsScreen`, `MatchInvitationsScreen`) vẫn đang lưu/đọc từ `MatchUiStore` trong RAM; nút mời người chơi trên `RecommendedPlayerDetailScreen` (mở từ cả `FindPlayersMapScreen` và `RecommendationListScreen`) đang bị chặn bởi hộp thoại thông báo; và Backend thiếu endpoint `GET /matches/my-invitations`.
2. **[Blocker #2 — P0] 4 bản Prisma Migration chưa được áp dụng & Thiếu dữ liệu Seed 10 cơ sở Đà Nẵng (`REQ-OPS-02`, `REQ-FAC-05`, `REQ-RATE-01..03`):**
   - Chưa áp dụng 4 bản migration `20261027*`–`20261101*` (cần thực hiện theo quy trình Backup → Kiểm chứng cô lập → Rollback plan) và `seed.ts` mới chỉ có 1 cơ sở Đà Nẵng thay vì 10 cơ sở Đà Nẵng (tỷ lệ 6–4 cho 2 Chủ sân, 2–4 sân/cơ sở = 20–40 sân, dùng khóa tự nhiên ổn định), khiến màn hình Home (`DemoCatalog` ID âm) và màn hình Map (`GET /facilities` ID dương) bị tách rời.
3. **[Blocker #3 — P0] Thuật toán FastAPI tại `/api/v1/match` đang bỏ qua `MatchmakingEngine` 5 yếu tố (`REQ-MM-02..03`):**
   - NestJS `CandidatesService` + `FastApiClient` đã gửi đủ 5 yếu tố (`skill` 6 trục, `location`/`max_distance_km`, `available_time_slots`, `playing_style`, `reliability_score`) và `matchmaking/app/services/matcher.py` đã cài đặt sẵn `MatchmakingEngine` 5 yếu tố, nhưng endpoint thật `POST /api/v1/match` trong `matchmaking/app/main.py:100-180` lại tự tính 2 yếu tố (`skill * 0.3 + distance * 0.25 + 0.45`) và `FastApiClient` đang khóa cứng `FASTAPI_BREAKDOWN_KEYS = ['distance_score', 'skill_score']`.
4. **[Blocker #4 — P1] Thiếu Trạng thái Thanh toán (`PaymentStatus`), Xác nhận Thu tiền tại sân & Lưới lịch 2D của Chủ sân (`REQ-FIN-03..06`):**
   - Prisma `Booking` chưa có `PaymentStatus` (`UNPAID`, `PAID`, `PENDING`, `CANCELLED`), chưa có API `PATCH /bookings/:id/payment-status` để Chủ sân xác nhận đã thu tiền tại sân (nên `collectedRevenue` đang là `null`), và tab Schedule ở chế độ Live của Chủ sân chưa hiển thị lưới 2D `DashboardScheduleGrid`.
5. **[Blocker #5 — P1] Biểu đồ Radar 6 trục tĩnh (`REQ-PROF-03..04`), Trợ lý Smash Scot AI dùng chuỗi cứng (`REQ-AI-01..04`) & Google Sign-In chưa nối (`REQ-AUTH-04`):**
   - `ProfileSkillRadar` đang vẽ file SVG tĩnh thay vì vẽ 6 trục (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve`) từ DB; `PlayersService.getMyProfile` chưa `include: { skill: true }`; `SmashScot` chưa có API LLM & công cụ truy vấn dữ liệu phân quyền theo role (`POST /ai/chat`); và nút Google Sign-In (`REQ-AUTH-04`) mới chỉ hiện SnackBar.
