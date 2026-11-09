# Existing work to preserve before the shared baseline

Snapshot: 2026-11-09, before setup-only preparation.

- Branch: `feature/SMM-41-FinalIntegrationTestingRelease`.
- HEAD / local develop / verified remote develop: `4090d678b7a9ef2d59521d811e8e44fbbcd872eb`.
- Divergence at inspection: 0 commits ahead, 0 behind.
- **69 modified tracked files and 54 untracked files already existed.** None of these files was changed or removed by baseline preparation. They are not part of HEAD yet.
- These paths are a preservation inventory, not blanket approval to merge every feature as complete. Review the P0.1 booking report and existing sprint audits separately.
- In particular, new Dart files depend on the untracked assets and tests below. A patch containing only tracked files would be incomplete.
- Local secret files such as `backend/.env` are ignored and deliberately absent from this inventory. Do not use `git add .` without reviewing the candidate files.

## Existing tracked modifications

- `backend/src/bookings/bookings.controller.ts`
- `backend/src/bookings/bookings.service.spec.ts`
- `backend/src/bookings/bookings.service.ts`
- `backend/src/bookings/dto/create-booking.dto.ts`
- `backend/src/facilities/operating-hours.service.ts`
- `backend/src/facilities/time-slots.service.spec.ts`
- `backend/src/facilities/time-slots.service.ts`
- `mobile/assets/icons/welcome_player_progress.svg`
- `mobile/ios/Runner/AppDelegate.swift`
- `mobile/lib/dev/presentation/dev_screen_explorer.dart`
- `mobile/lib/dev/presentation/dev_testing_hub.dart`
- `mobile/lib/features/auth/screens/create_account_screen.dart`
- `mobile/lib/features/auth/screens/forgot_password_screen.dart`
- `mobile/lib/features/auth/screens/login_screen.dart`
- `mobile/lib/features/auth/screens/player_profile_screen.dart`
- `mobile/lib/features/auth/screens/player_welcome_screen.dart`
- `mobile/lib/features/auth/widgets/auth_header.dart`
- `mobile/lib/features/auth/widgets/primary_button.dart`
- `mobile/lib/features/auth/widgets/role_welcome_layout.dart`
- `mobile/lib/features/auth/widgets/social_button.dart`
- `mobile/lib/features/auth/widgets/sprint2_presentation.dart`
- `mobile/lib/features/booking/screens/booking_detail_screen.dart`
- `mobile/lib/features/booking/screens/booking_facility_schedule_screen.dart`
- `mobile/lib/features/booking/screens/booking_flow_screen.dart`
- `mobile/lib/features/booking/screens/booking_history_screen.dart`
- `mobile/lib/features/booking/screens/booking_success_screen.dart`
- `mobile/lib/features/booking/screens/booking_summary_screen.dart`
- `mobile/lib/features/booking/services/live_booking_service.dart`
- `mobile/lib/features/booking/widgets/live_facility_schedule.dart`
- `mobile/lib/features/court_map/exploration_data.dart`
- `mobile/lib/features/court_map/screens/court_preview_screen.dart`
- `mobile/lib/features/court_map/screens/find_courts_map_screen.dart`
- `mobile/lib/features/court_map/screens/find_players_map_screen.dart`
- `mobile/lib/features/court_map/widgets/court_maplibre_map.dart`
- `mobile/lib/features/dashboard/data/dashboard_repository.dart`
- `mobile/lib/features/dashboard/screens/dashboard_screen.dart`
- `mobile/lib/features/dashboard/widgets/dashboard_assets.dart`
- `mobile/lib/features/dashboard/widgets/dashboard_widgets.dart`
- `mobile/lib/features/facility/screens/add_edit_court_screen.dart`
- `mobile/lib/features/facility/screens/facility_detail_screen.dart`
- `mobile/lib/features/facility/screens/operating_hours_screen.dart`
- `mobile/lib/features/facility/widgets/facility_card.dart`
- `mobile/lib/features/feedback/data/feedback_repository.dart`
- `mobile/lib/features/feedback/screens/rating_history_screen.dart`
- `mobile/lib/features/feedback/widgets/feedback_widgets.dart`
- `mobile/lib/features/match/screens/create_match_screen.dart`
- `mobile/lib/features/match/screens/match_detail_open_screen.dart`
- `mobile/lib/features/match/screens/match_invitations_screen.dart`
- `mobile/lib/features/match/screens/match_join_requests_screen.dart`
- `mobile/lib/features/match/screens/match_participant_list_screen.dart`
- `mobile/lib/features/match/widgets/match_card.dart`
- `mobile/lib/features/navigation/player_bottom_navigation.dart`
- `mobile/lib/features/recommendation/data/recommendation_repository.dart`
- `mobile/lib/features/recommendation/models/recommended_player.dart`
- `mobile/lib/features/recommendation/screens/recommended_player_detail_screen.dart`
- `mobile/lib/features/recommendation/widgets/recommendation_widgets.dart`
- `mobile/pubspec.lock`
- `mobile/pubspec.yaml`
- `mobile/test/court_maplibre_test.dart`
- `mobile/test/dashboard_flow_test.dart`
- `mobile/test/feedback_flow_test.dart`
- `mobile/test/find_courts_map_screen_test.dart`
- `mobile/test/live_booking_test.dart`
- `mobile/test/map_exploration_flow_test.dart`
- `mobile/test/match_screens_test.dart`
- `mobile/test/player_bottom_navigation_test.dart`
- `mobile/test/recommendation_flow_test.dart`
- `mobile/test/role_welcome_screen_test.dart`
- `mobile/test/support/fake_court_map_platform.dart`

## Existing untracked files

- `backend/src/bookings/booking-time.ts`
- `backend/src/bookings/bookings.integration.live.spec.ts`
- `docs/audits/FINAL-SPRINT-COMPLETION-SCORECARD.md`
- `docs/audits/FINAL-SPRINT-EXECUTION-BACKLOG.md`
- `docs/audits/FINAL-SPRINT-REQUIREMENT-MATRIX.md`
- `docs/audits/P0.1-BOOKING-INTEGRATION.md`
- `docs/audits/S-MATCH-FINAL-SPRINT-BACKLOG.md`
- `docs/audits/S-MATCH-FINAL-SPRINT-READINESS.md`
- `docs/audits/S-MATCH-VERIFICATION-REPORT.md`
- `mobile/assets/sprint10/courts/an_hai.png`
- `mobile/assets/sprint10/courts/an_khe.png`
- `mobile/assets/sprint10/courts/cam_le.png`
- `mobile/assets/sprint10/courts/hai_chau.png`
- `mobile/assets/sprint10/courts/hoa_cuong.png`
- `mobile/assets/sprint10/courts/hoa_khanh.png`
- `mobile/assets/sprint10/courts/hoa_xuan.png`
- `mobile/assets/sprint10/courts/ngu_hanh_son.png`
- `mobile/assets/sprint10/courts/son_tra.png`
- `mobile/assets/sprint10/courts/thanh_khe.png`
- `mobile/assets/sprint10/icons/bag.svg`
- `mobile/assets/sprint10/icons/bell.svg`
- `mobile/assets/sprint10/icons/book.svg`
- `mobile/assets/sprint10/icons/cap.svg`
- `mobile/assets/sprint10/icons/pin.svg`
- `mobile/assets/sprint10/icons/search.svg`
- `mobile/assets/sprint10/icons/shuttle.svg`
- `mobile/assets/sprint10/icons/users.svg`
- `mobile/assets/sprint10/learning/badminton_shoes.png`
- `mobile/assets/sprint10/learning/coach_lan.png`
- `mobile/assets/sprint10/learning/coach_minh.png`
- `mobile/assets/sprint10/learning/footwork_training.png`
- `mobile/assets/sprint10/learning/net_play.png`
- `mobile/assets/sprint10/learning/replacement_grips.png`
- `mobile/assets/sprint10/learning/shuttlecocks.png`
- `mobile/assets/sprint10/learning/smash_technique.png`
- `mobile/assets/sprint10/learning/training_course.png`
- `mobile/assets/sprint10/learning/training_racket.png`
- `mobile/assets/sprint9/owner_today_calendar.svg`
- `mobile/assets/sprint9/owner_today_chevron.svg`
- `mobile/lib/core/theme/app_motion_widgets.dart`
- `mobile/lib/features/court_map/widgets/native_court_layers.dart`
- `mobile/lib/features/court_map/widgets/native_player_layers.dart`
- `mobile/lib/features/player_experience/data/demo_booking_service.dart`
- `mobile/lib/features/player_experience/data/demo_catalog.dart`
- `mobile/lib/features/player_experience/screens/courts_screens.dart`
- `mobile/lib/features/player_experience/screens/learning_screens.dart`
- `mobile/lib/features/player_experience/screens/player_home_screen.dart`
- `mobile/lib/features/player_experience/screens/shop_screens.dart`
- `mobile/lib/features/player_experience/widgets/experience_widgets.dart`
- `mobile/lib/features/player_experience/widgets/smash_scot.dart`
- `mobile/test/app_motion_widgets_test.dart`
- `mobile/test/booking_map_integration_test.dart`
- `mobile/test/player_discovery_test.dart`
- `mobile/test/sprint10_experience_test.dart`

## Completed changes with existing verification to preserve

- P0.1 booking: real facility/court selection, dated availability, configured pricing, PostgreSQL transaction/locking, Player history and Owner feed. See [P0.1 report](../audits/P0.1-BOOKING-INTEGRATION.md). No live booking test was re-run during baseline preparation.
- Existing Flutter UI/motion changes, native map layers and Simulator pinch adapter, screen navigation, fixture catalogs and session-only demo booking. The complete Flutter widget suite passed during preparation; this does not certify every unfinished Final Sprint feature.
- Existing feedback/recommendation repositories and layouts, tests, documentation and assets. Preserve them while keeping their incomplete live workflows assigned to the approved backlog owners.

## Review boundaries

Preparation modifies only setup/build configuration and adds handoff documentation. No original file in `backend/src`, `mobile/lib`, `mobile/test`, `matchmaking/app`, `matchmaking/test`, or `backend/prisma` was altered by this preparation. All original files were checked against their initial SHA-256 digests; none was removed. The approved backlog and audit documents remain unchanged.
