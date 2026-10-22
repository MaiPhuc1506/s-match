# Báo cáo fix Recommendation Integration — 23/10/2026

Nhánh thực hiện: `feature/SMM-33-feedback-rating-mobile`.
Phạm vi: hoàn thiện kết nối SMM-29/30/32 và kiểm thử lại SMM-31.

## Thay đổi theo file

| File | Nội dung |
| --- | --- |
| `backend/src/matchmaking.service.ts` | Inject `RecommendationHistoryService`; thêm `saveSearch()` để lưu đúng người đang đăng nhập, snapshot tiêu chí, số ứng viên và danh sách kết quả cuối cùng theo thứ hạng. Lưu cả phiên không có ứng viên/không có kết quả/hồ sơ đã biến mất. Không lưu khi bước tìm kiếm thất bại. Lỗi ghi lịch sử trả 503 với thông báo chung. |
| `backend/src/matchmaking.module.ts` | Import `RecommendationHistoryModule` để NestJS cấp dependency của service lịch sử. |
| `mobile/lib/features/recommendation/data/recommendation_repository.dart` | Đọc nickname/fullName, skillLevel, avatarUrl từ `matchedUsers[].profile`. Nickname trống thì dùng fullName; thiếu tên dùng cơ chế `Player #id` sẵn có. Giữ nguyên điểm và thứ tự server. Nearby chỉ bổ sung distanceKm; lỗi kết nối nearby không làm mất tên/ảnh/trình độ. Lỗi 401/403 vẫn được xử lý như lỗi quyền/phiên. |
| `matchmaking/requirements.txt` | Khai báo `pydantic-settings==2.2.1`, dependency đã được code config sử dụng nhưng chưa có trong danh sách cài đặt. |
| `backend/src/matchmaking.service.spec.ts` | Kiểm tra nội dung/thứ tự lưu, phiên rỗng, loại hồ sơ không còn hợp lệ, không lưu khi upstream lỗi và thông báo 503 khi ghi lịch sử thất bại. |
| `backend/src/matchmaking.http.spec.ts` | Chạy controller/guard/service thật với mock ở biên DB/HTTP; xác minh nested create của lịch sử và lỗi ghi DB. |
| `backend/src/matchmaking/database-candidate-provider.spec.ts` | Cập nhật dependency lịch sử trong test ghép candidate provider và gateway. |
| `backend/src/recommendation-history/recommendation-integration.live.spec.ts` | Thêm 3 bài test opt-in sử dụng PostgreSQL và FastAPI thật, đăng ký/đăng nhập thật. Tự tạo và dọn tài khoản riêng. |
| `mobile/test/recommendation_flow_test.dart` | Kiểm tra dùng profile từ kết quả xếp hạng, ưu tiên nickname, avatar, khoảng cách bổ sung, nearby mất kết nối, thiếu dữ liệu hiển thị, thứ tự/điểm 0, kết quả rỗng và lỗi HTTP 401/403/503/504. Giữ các widget test navigation/layout sẵn có. |
| `backend/src/matchmaking/README.md` | Cập nhật mô tả lưu lịch sử, lỗi, migration, lệnh test thật và cách bật API thật trong Dev Hub. |

## Thao tác môi trường đã hoàn thành

- Chạy `npm run db:generate` thành công.
- Áp dụng migration có sẵn `20261016120000_smm_32_recommendation_history` bằng `npm run db:deploy` lên PostgreSQL local. Không tạo migration mới.
- Cài requirements vào `matchmaking/.venv`, bao gồm dependency còn thiếu.
- Khởi chạy FastAPI tạm trên cổng 18080 để test, sau đó đã dừng.
- Tài khoản test đã dọn sạch: truy vấn xác nhận còn 0 tài khoản mang prefix test.

## Kết quả kiểm thử

| Kiểm tra | Kết quả |
| --- | --- |
| 5 suite backend: gateway service, HTTP, candidate adapter, FastAPI client, history service | 150/150 pass |
| Tích hợp API với PostgreSQL + FastAPI thật | 3/3 pass |
| Toàn bộ test Python trong `matchmaking/` | 11/11 pass |
| Flutter recommendation widget/repository tests | 16/16 pass |
| `npm run build` | Pass |
| `flutter analyze lib/features/recommendation test/recommendation_flow_test.dart` | Không có issue |
| `git diff --check` | Pass |

Luồng tích hợp thật đã kiểm tra: đăng ký → đăng nhập → lấy giờ rảnh → tìm đối thủ → so sánh danh sách/điểm/rank với DB lịch sử → phân trang/chi tiết → cập nhật INVITED/ACCEPTED → thống kê → xóa phiên và cascade kết quả. Tài khoản khác không đọc/sửa/xóa được phiên. Tìm rỗng vẫn tạo lịch sử. FastAPI mất kết nối, tiêu chí sai và phiên đăng nhập bị thu hồi không tạo thêm lịch sử.

## Giới hạn và hành vi cần nắm

- Nếu lưu lịch sử lỗi, toàn bộ request trả 503 dù đã tính được điểm; client có thể thử lại. Mỗi request thành công là một phiên riêng, chưa có idempotency key chống trùng khi người dùng gửi lại request.
- Test mobile chạy tự động ở mức widget/repository; chưa thao tác thủ công trên simulator/điện thoại.
- Dev Hub mặc định dùng fixture. Để tìm đối thủ qua API thật: `flutter run -t lib/main_dev.dart --dart-define=SPRINT7_LIVE_API=true` từ `mobile/`.
- Mời trực tiếp người được gợi ý và giao diện Feedback/Rating SMM-33 nằm ngoài đợt fix này.
- Chưa commit, push hoặc merge.
