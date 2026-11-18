# S-MATCH — FINAL SPRINT IMPLEMENTATION CHECKLIST

> **Scope:** Actionable engineering & QA checklist derived directly from current Flutter, NestJS, Prisma/PostgreSQL, and FastAPI source code.
> **Purpose:** Answer three practical questions for every feature (**What is missing?**, **What needs improvement/fixing?**, **What must be tested?**) and provide a ready-to-execute checklist for all 4 team members.

---

## 1. Missing Features

Features or sub-workflows that do not yet exist in production code (or exist only as hardcoded UI demos with no backend/database implementation):

| # | Feature Area | Status | What Is Missing in Code | Priority |
|---|---|---|---|---|
| **F1** | **Google Sign-In OAuth** | `MISSING` | • **Mobile:** `google_sign_in` dependency is absent in `mobile/pubspec.yaml`; Google button in `mobile/lib/features/auth/screens/login_screen.dart:181-185` only triggers a demo `SnackBar`.<br>• **Backend:** `backend/src/auth/auth.controller.ts` has no `POST /auth/google` endpoint; `AuthService` has no Google ID token verification or user upsert logic. | **P1** |
| **F6** | **Match Lifecycle Mobile API Integration & My-Invitations Endpoint** | `DEMO` (Mobile) / `PARTIAL` (Backend) | • **Mobile:** `CreateMatchScreen` (`create_match_screen.dart:796`), `MatchListScreen`, `MatchDetailOpenScreen`, `MatchJoinRequestsScreen`, `MatchInvitationsScreen`, and `MatchParticipantListScreen` read/write in-memory `MatchUiStore.instance` instead of calling Backend `/matches` APIs.<br>• **Backend:** `backend/src/matches/matches.controller.ts` lacks `GET /matches/my-invitations` (for invitees to fetch `PRIVATE` and `OPEN` matches where they have an `INVITED` record) and `GET /matches/my` (for hosts/participants to list their active/completed matches). | **P0** |
| **F9** | **6-Axis Skill Assessment API & Dynamic Radar Chart** | `DEMO` | • **Backend:** `PlayersService.getMyProfile` (`backend/src/players/players.service.ts:10-20`) does not include `skill: true` inside `playerProfile`; `PlayersController` has no `PUT /players/profile/me/skill` endpoint to upsert the 6 axes (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve`).<br>• **Mobile:** `ProfileSkillRadar` (`mobile/lib/features/auth/widgets/profile_skill_radar.dart:53-111`) renders static SVG assets (`profile_radar_data.svg`) instead of a dynamic `CustomPainter` polygon; `SkillAssessmentScreen` (`skill_assessment_screen.dart:242-310`) uses static constants and shows a preview `SnackBar` on save. | **P1** |
| **F12** | **Finance Payment Status & Collected Revenue** | `MISSING` | • **Database:** `Booking` model in `backend/prisma/schema.prisma:172-193` has no `paymentStatus` field (`PaymentStatus` enum: `UNPAID`, `PAID`, `PENDING`, `CANCELLED`) or `paidAt` timestamp.<br>• **Backend:** No `PATCH /bookings/:id/payment-status` endpoint for Court Owners to confirm pay-at-court collection; `RevenueAnalyticsService` (`backend/src/analytics/revenue-analytics.service.ts:95,164`) hardcodes `collectedRevenue: null`.<br>• **Mobile:** `OwnerBookingDetailScreen` (`dashboard_screen.dart:1750-1915`) has no action button to mark a booking as `PAID`. | **P1** |
| **F13** | **Smash Scot AI Backend & Role-Aware Data Tools** | `DEMO` | • **Backend:** No `AiModule` or `POST /ai/chat` endpoint exists in `backend/src/app.module.ts`; no server-side RBAC tool handlers (`PLAYER` vs `COURT_OWNER` vs `ADMIN`).<br>• **Mobile:** `SmashScotChat.send` (`mobile/lib/features/player_experience/widgets/smash_scot.dart:117-135`) uses local `if (lower.contains(...))` keyword matching over `DemoCatalog`; `SmashScot` is not mounted on `DashboardScreen` for Court Owners/Admins. | **P1** |
| **F14** | **Coach/Courses & Shop Directory Backend Catalog** | `DEMO` | • **Database & Backend:** No `Coach`, `Course`, or `ShopDirectoryEntry` tables in `schema.prisma`; no read-only `GET /catalog/courses` or `GET /catalog/shops` endpoints.<br>• **Mobile:** `LearningScreen`, `LearningDetailScreen`, `ShopDirectoryScreen`, and `ShopDetailScreen` read exclusively from `DemoCatalog` (`demo_catalog.dart`). *(Note: Shop is strictly a directory using external contact links via `url_launcher`—no cart, orders, or checkout).* | **P2** |

---

## 2. Features Needing Fixes / Improvements (15-Feature Code Inspection)

Detailed inspection of all 15 features across Flutter (`mobile/`), NestJS (`backend/`), Prisma (`backend/prisma/`), and FastAPI (`matchmaking/`):

### Feature 1: Authentication (Login, Register, Sessions, Google Sign-In, Player/Court Owner Roles)
- **Current Status:** `PARTIAL` (**Priority: P1**)
- **Working in Code:**
  - `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh` (with `RefreshSession` token rotation & revocation), and `POST /auth/logout` in `backend/src/auth/auth.controller.ts` & `auth.service.ts`.
  - Role guards (`PLAYER`, `COURT_OWNER`, `ADMIN`) in `backend/src/auth/guards/roles.guard.ts` and role-aware welcome routing in `mobile/lib/features/auth/widgets/role_welcome_layout.dart`.
- **What Is Missing:**
  - Google Sign-In SDK & `POST /auth/google` endpoint (`TASK-M1-06B`, `TASK-M3-05`).
- **Bugs / Improvements Needed:**
  - `LoginScreen` SMS button (`login_screen.dart:190-194`) and `ForgotPasswordScreen` (`forgot_password_screen.dart:117-242`, hardcoded code `2846`) are unbacked UI demos—label them clearly as `[Demo Preview — Email & Google Sign-In Supported]` so evaluators do not mistake them for live OTP endpoints.
- **API / DB Integration Needed:** `POST /auth/google` verifying Google ID tokens and linking/creating `User` + `RefreshSession`.
- **Exact Files / Modules:** `mobile/pubspec.yaml`, `mobile/lib/features/auth/screens/login_screen.dart`, `mobile/lib/features/auth/screens/forgot_password_screen.dart`, `mobile/lib/core/services/auth_service.dart`, `backend/src/auth/auth.controller.ts`, `backend/src/auth/auth.service.ts`.
- **Tests Required:** Unit tests for Google token verification & role assignment; E2E login/session persistence for Player and Court Owner.

### Feature 2: Player Home, Explore, Search & Navigation
- **Current Status:** `DEMO / PARTIAL` (**Priority: P0**)
- **Working in Code:**
  - `PlayerHomeScreen`, `PlayerBottomNavigation`, `ExploreCourtsScreen`, and `ExperienceSearchScreen` layouts and navigation transitions work smoothly.
- **What Is Missing:**
  - Live API binding to `GET /facilities` on Player Home, Explore Courts, and Search screens.
- **Bugs / Improvements Needed:**
  - `PlayerHomeScreen` (`mobile/lib/features/player_experience/screens/player_home_screen.dart:19,176`), `ExploreCourtsScreen` (`courts_screens.dart:23-95`), and `ExperienceSearchScreen` (`player_home_screen.dart:334-372`) read from `demoCatalogProvider` (`DemoCatalog` with negative IDs `-1001`..`-1010`) and open `DemoCourtDetailScreen` instead of live `BookingFacilityScheduleScreen`.
  - The `"Explore Map"` hero button on `PlayerHomeScreen:125` pushes `DemoCourtsMapScreen` instead of the live MapLibre `FindCourtsMapScreen`.
- **API / DB Integration Needed:** Replace `demoCatalogProvider` court lists in live mode with `FacilityApiService.getFacilities()` (`GET /facilities`) and route court cards to `BookingFacilityScheduleScreen(facilityId: facility.id)`.
- **Exact Files / Modules:** `mobile/lib/features/player_experience/screens/player_home_screen.dart`, `mobile/lib/features/player_experience/screens/courts_screens.dart`, `mobile/lib/features/facility/services/facility_api_service.dart`.
- **Tests Required:** Simulator E2E test verifying Player Home -> Explore/Search -> selects real Da Nang facility -> opens live schedule and books a slot.

### Feature 3: Facilities, Courts, Operating Hours & Time Slots
- **Current Status:** `WORKING` (**Priority: P0**)
- **Working in Code:**
  - `FacilitiesController` (`POST /facilities`, `GET /facilities`, `GET /facilities/my`, `GET /facilities/:id`, `PATCH /facilities/:id`, `DELETE /facilities/:id`, `POST/PATCH/DELETE /facilities/:id/courts`), `OperatingHoursController` (`PUT/GET /facilities/:id/operating-hours`), and `TimeSlotsController` (`GET /facilities/:id/courts/:courtId/time-slots/availability?date=`).
  - Mobile screens in `mobile/lib/features/facility/screens/` (`facility_list_screen.dart`, `create_edit_facility_screen.dart`, `court_management_screen.dart`, `operating_hours_screen.dart`).
- **What Is Missing:**
  - Full Da Nang seed dataset in `backend/prisma/seed.ts` (currently seeds only 1 Owner and 1 Facility with `id: 1`).
- **Bugs / Improvements Needed:**
  - Expand `backend/prisma/seed.ts` to seed **2 Court Owners** (`owner1@smatch.vn` managing 6 facilities, `owner2@smatch.vn` managing 4 facilities), **10 Da Nang Facilities** across Hai Chau, Son Tra, Ngu Hanh Son, Thanh Khe, Cam Le, and Lien Chieu, with **2–4 Courts per facility (20–40 Courts total)**, Operating Hours (`06:00–22:00`), and hourly `TimeSlot`s using stable natural keys (`ownerId + facilityName` and `facilityId + courtName`).
  - Fix `0-byte` empty test file `backend/src/facilities/facilities.service.spec.ts` which currently causes `jest` to fail with `Your test suite must contain at least one test`.
- **API / DB Integration Needed:** Idempotent seed execution (`npx prisma db seed`) against PostgreSQL.
- **Exact Files / Modules:** `backend/prisma/seed.ts`, `backend/src/facilities/facilities.service.spec.ts`.
- **Tests Required:** Jest unit test suite for `FacilitiesService` (create, update, ownership check, court CRUD) and seed idempotency verification.

### Feature 4: MapLibre (Registered Facilities, Markers, Court Details, Booking from Map)
- **Current Status:** `WORKING` (**Priority: P1**)
- **Working in Code:**
  - `CourtMaplibreMap` (`mobile/lib/features/court_map/widgets/court_maplibre_map.dart`), `native_court_layers.dart`, `FindCourtsMapScreen` (`find_courts_map_screen.dart`), and `CourtPreviewScreen` (`court_preview_screen.dart`).
  - Loads live facilities from `GET /facilities`, renders interactive MapLibre symbol/circle layers, opens court preview bottom sheet, and navigates with real `facilityId` to `BookingFacilityScheduleScreen`.
- **What Is Missing:** None in code; depends on the 10 Da Nang facilities seed (`TASK-M2-02`) to populate markers across Da Nang.
- **Bugs / Improvements Needed:** Ensure `PlayerHomeScreen` map entry point routes to `FindCourtsMapScreen` instead of `DemoCourtsMapScreen`.
- **API / DB Integration Needed:**Already integrated with `GET /facilities`.
- **Exact Files / Modules:** `mobile/lib/features/court_map/screens/find_courts_map_screen.dart`, `mobile/lib/features/court_map/screens/court_preview_screen.dart`.
- **Tests Required:** Simulator E2E test verifying all 10 Da Nang facility pins render on MapLibre and tapping a pin opens the real court schedule.

### Feature 5: Booking (Price, Availability, Confirmation, History, Cancellation, Double-Booking Prevention)
- **Current Status:** `WORKING / PARTIAL` (**Priority: P0**)
- **Working in Code:**
  - Server-side continuous slot validation, operating hours check, Vietnam time (`UTC+7`) validation, server-side `totalPrice` calculation, and pessimistic row lock (`SELECT id FROM "Court" WHERE id = ... FOR UPDATE`) in `backend/src/bookings/bookings.service.ts:61-151`.
  - `POST /bookings`, `GET /bookings/my`, `GET /bookings/owner`, `PATCH /bookings/:id/cancel` in `BookingsController`.
  - Mobile `LiveBookingService`, `BookingFacilityScheduleScreen`, `BookingConfirmationScreen`, and `BookingHistoryScreen(live: true)`.
- **What Is Missing:**
  - Live API call wired to the **"Cancel Booking"** button in `BookingDetailScreen`.
- **Bugs / Improvements Needed:**
  - In `mobile/lib/features/booking/screens/booking_detail_screen.dart:204-221`, tapping **"Cancel Booking"** only mutates the local preview store (`BookingFlowScope.of(context).cancelBooking(booking.id)`). When viewing a live booking from `BookingHistoryScreen(live: true)`, it must call `LiveBookingService.instance.cancelBooking(booking.id)` (`PATCH /bookings/:id/cancel`) and refresh the booking status.
- **API / DB Integration Needed:** Wire `LiveBookingService.instance.cancelBooking` into `BookingDetailScreen`.
- **Exact Files / Modules:** `mobile/lib/features/booking/screens/booking_detail_screen.dart`, `mobile/lib/features/booking/services/live_booking_service.dart`, `backend/src/bookings/bookings.service.ts`.
- **Tests Required:** Concurrent `Promise.all` double-booking integration test (1 `201 Created`, 1 `409 Conflict`) and Simulator E2E booking creation + cancellation test.

### Feature 6: Open/Private Match (Creation, Invitations, Joining, Host Approvals, Participant Management, Completion)
- **Current Status:** `PARTIAL — Backend WORKING, Mobile DEMO` (**Priority: P0**)
- **Working in Code:**
  - Backend `MatchesController` & `OpenMatchesController` (`backend/src/matches/matches.controller.ts`) implement `POST /matches`, `POST /bookings/:bookingId/open-match`, `GET /matches/open`, `GET /matches/:id`, `PATCH /matches/:id`, `PATCH /matches/:id/cancel`, `PATCH /matches/:id/complete`, `POST /matches/:id/invite`, `POST /matches/:id/join-request`, `PATCH /matches/:id/invitations/accept`, `PATCH /matches/:id/invitations/reject`, `PATCH /matches/:id/requests/:userId/approve`, `PATCH /matches/:id/requests/:userId/reject`, and `PATCH /open-matches/:id/leave`.
  - Mobile `LiveMatchFeedbackScreen` (`mobile/lib/features/feedback/screens/live_match_feedback_screen.dart`) already calls `PATCH /matches/:id/complete`.
- **What Is Missing:**
  - Backend: `GET /matches/my-invitations` and `GET /matches/my` in `MatchesController` / `MatchesService` so players can discover `PRIVATE` and `OPEN` matches they were invited to or are participating in.
  - Mobile: Live REST service (`MatchApiService`) replacing `MatchUiStore.instance` across all 6 match screens.
- **Bugs / Improvements Needed:**
  - `CreateMatchScreen` (`create_match_screen.dart:796`) saves new matches only to `MatchUiStore.instance.createMatch(...)` instead of calling `POST /matches` (or `POST /bookings/:bookingId/open-match`).
  - `MatchListScreen`, `MatchDetailOpenScreen`, `MatchJoinRequestsScreen`, `MatchInvitationsScreen`, and `MatchParticipantListScreen` read/write in-memory mock data in `MatchUiStore`.
  - `RecommendedPlayerDetailScreen` (`mobile/lib/features/recommendation/screens/recommended_player_detail_screen.dart:15-42`) shows a dialog stating direct invitations are unsupported instead of letting the host select one of their active matches and calling `POST /matches/:id/invite`.
- **API / DB Integration Needed:** Add `GET /matches/my-invitations` & `GET /matches/my` on Backend; connect all Mobile match screens + player invite action to `/matches/*`.
- **Exact Files / Modules:** `backend/src/matches/matches.controller.ts`, `backend/src/matches/matches.service.ts`, `mobile/lib/features/match/screens/create_match_screen.dart`, `match_list_screen.dart`, `match_detail_open_screen.dart`, `match_join_requests_screen.dart`, `match_invitations_screen.dart`, `match_participant_list_screen.dart`, `mobile/lib/features/recommendation/screens/recommended_player_detail_screen.dart`.
- **Tests Required:** Backend integration test for full Open & Private match lifecycles (`INVITED` -> `ACCEPTED`, `REQUESTED` -> `ACCEPTED`, capacity enforcement, `PATCH /matches/:id/complete`); Simulator E2E test with two player accounts.

### Feature 7: Find Players (Availability, Location Filtering, Privacy, Player Profiles)
- **Current Status:** `PARTIAL` (**Priority: P0 / P1**)
- **Working in Code:**
  - `GET /candidates/nearby` and `PATCH /candidates/me/location` exist in `backend/src/candidates/candidates.controller.ts`.
  - `FindPlayersMapScreen` (`mobile/lib/features/court_map/screens/find_players_map_screen.dart`) and `PlayerDiscoveryOverlay` fetch nearby candidates and filter by distance radius and skill level.
- **What Is Missing:**
  - `availableNow` boolean calculation in `CandidatesService.findNearby` response.
  - Mobile call to `PATCH /candidates/me/location` when opening Player Discovery.
- **Bugs / Improvements Needed:**
  - **Privacy leak (P0):** `CandidatesService.findNearby` (`backend/src/candidates/candidates.service.ts:114-115`) returns raw `latitude` and `longitude` of other players in the HTTP response. Strip exact coordinates (or round to coarse 2-decimal district center) and return only `distanceKm` + `district` + `availableNow`.
  - Because `availableNow` is missing from `GET /candidates/nearby`, `FindPlayersMapScreen` (`find_players_map_screen.dart:55-61,232-244`) hardcodes `availableNow: false` and disables the `"Available Now"` filter chip.
- **API / DB Integration Needed:** Compute `availableNow` from the candidate's `Availability` records in `CandidatesService.findNearby`, strip raw `latitude`/`longitude`, and wire `availableNow` filter + `PATCH /candidates/me/location` in Flutter.
- **Exact Files / Modules:** `backend/src/candidates/candidates.service.ts`, `mobile/lib/features/court_map/data/exploration_data.dart`, `mobile/lib/features/court_map/screens/find_players_map_screen.dart`.
- **Tests Required:** Unit/integration test asserting `GET /candidates/nearby` response contains `distanceKm` and `availableNow` but never raw `latitude`/`longitude`; Simulator E2E test for distance, skill, and availability filters.

### Feature 8: Matchmaking (Five-Factor Scoring, FastAPI Integration, Actual Recommendation Results)
- **Current Status:** `PARTIAL` (**Priority: P0**)
- **Working in Code:**
  - `MatchmakingEngine` in `matchmaking/app/services/matcher.py:13-220` already implements the complete 5-factor weighted algorithm (`skill` 0.35, `time` 0.25, `distance` 0.20, `style` 0.10, `reliability` 0.10) with Haversine distance, time overlap ratio, and cosine skill similarity.
  - NestJS `CandidatesService` (`backend/src/candidates/candidates.service.ts`) already builds and sends all 5 factors in the request payload to FastAPI `POST /api/v1/match`.
  - Mobile `ApiRecommendationRepository` (`mobile/lib/features/recommendation/data/recommendation_repository.dart`) already calls NestJS `POST /matchmaking/recommend`.
- **What Is Missing:**
  - Delegation from `matchmaking/app/main.py` (`POST /api/v1/match`) to `MatchmakingEngine`, and forwarding of all 5 breakdown scores through NestJS `FastApiClient` and `MatchmakingService`.
- **Bugs / Improvements Needed:**
  - **Critical Scoring Bug (P0):** `matchmaking/app/main.py:100-180` (`POST /api/v1/match`) ignores `MatchmakingEngine` and runs a 2-factor inline formula with a hardcoded `+ 0.45` constant (`skill_similarity * 0.3 + (distance_score / 100.0) * 0.25 + 0.45`), returning only 2 breakdown keys (`distance_score`, `skill_score`).
  - **Contract Truncation Bug (P0):** `backend/src/matchmaking/fastapi.client.ts:10,85-99` enforces `FASTAPI_BREAKDOWN_KEYS = ['distance_score', 'skill_score']` and strips the `breakdown` object before returning to `MatchmakingService` (`backend/src/matchmaking.service.ts`).
  - Local Python `.venv` (`matchmaking/.venv`) is missing `numpy`, causing local `pytest` to fail with `ModuleNotFoundError: No module named 'numpy'`.
- **API / DB Integration Needed:** Wire `POST /api/v1/match` in `main.py` to `MatchmakingEngine.find_matches()` and return all 5 breakdown keys (`skill_score`, `time_score`, `distance_score`, `style_score`, `reliability_score`) end-to-end through `FastApiClient` and `MatchmakingService` to Flutter.
- **Exact Files / Modules:** `matchmaking/app/main.py`, `matchmaking/app/services/matcher.py`, `backend/src/matchmaking/fastapi.client.ts`, `backend/src/matchmaking.service.ts`, `mobile/lib/features/recommendation/data/recommendation_repository.dart`.
- **Tests Required:** FastAPI `pytest` suite verifying 5-factor weights, zero hardcoded `+ 0.45`, and 5 breakdown keys; NestJS `FastApiClient` unit tests; Simulator E2E recommendation screen verification.

### Feature 9: Skill Assessment (Six-Axis Skill Data, Radar Chart, Updates)
- **Current Status:** `DEMO / PARTIAL` (**Priority: P1**)
- **Working in Code:**
  - Prisma `Skill` model (`backend/prisma/schema.prisma:103-114`) stores all 6 axes (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve`) linked 1-to-1 with `PlayerProfile`.
- **What Is Missing:**
  - Backend `PUT /players/profile/me/skill` endpoint and `include: { skill: true }` in `PlayersService.getMyProfile`.
  - Dynamic `CustomPainter` 6-axis radar chart in `ProfileSkillRadar` and live save integration in `SkillAssessmentScreen`.
- **Bugs / Improvements Needed:**
  - `PlayersService.getMyProfile` (`backend/src/players/players.service.ts:10-20`) includes `playerProfile: true` without nested `skill: true`, so `GET /players/profile/me` never returns the player's 6 skill axes.
  - `ProfileSkillRadar` (`mobile/lib/features/auth/widgets/profile_skill_radar.dart:53-111`) renders static SVG illustrations instead of plotting the player's 6 numeric skill scores.
  - `SkillAssessmentScreen` (`mobile/lib/features/auth/screens/skill_assessment_screen.dart:242-310`) does not persist changes to Backend.
- **API / DB Integration Needed:** Add `PUT /players/profile/me/skill` (validating 6 axes in `0..100` and recomputing `PlayerProfile.skillScore` average) and connect `SkillAssessmentScreen` + `ProfileSkillRadar` + `ProfileScreen`.
- **Exact Files / Modules:** `backend/src/players/players.controller.ts`, `backend/src/players/players.service.ts`, `mobile/lib/features/auth/widgets/profile_skill_radar.dart`, `mobile/lib/features/auth/screens/skill_assessment_screen.dart`, `mobile/lib/features/auth/screens/profile_screen.dart`.
- **Tests Required:** Unit test for `PUT /players/profile/me/skill` boundary validation (`0..100`) and verify that post-match feedback does **not** alter technical `Skill` axes; Simulator E2E test updating sliders and verifying radar polygon redraws.

### Feature 10: Feedback / Rating (Post-Match Feedback, Rating History, Reliability)
- **Current Status:** `PARTIAL — Code Wired, DB Migrations Pending` (**Priority: P0**)
- **Working in Code:**
  - Backend `RatingsController` & `RatingsService` (`POST /ratings`, `GET /ratings/users/:id/summary`, `GET /ratings/users/:id/history`, `GET /ratings/pending`) in `backend/src/ratings/`.
  - Mobile `ApiFeedbackRepository` & `RatingApi` (`mobile/lib/features/feedback/data/feedback_repository.dart`, `rating_api.dart`, `live_match_feedback_screen.dart`, `rating_history_screen.dart`) are **already wired to the real Backend APIs**.
  - Post-match ratings update `PlayerRating` and `PlayerProfile.reliabilityScore` without mutating the 6 technical `Skill` axes.
- **What Is Missing:**
  - Applying the 4 pending Prisma migrations in the local PostgreSQL database (`20261027120000_add_match_feedback`, `20261027120000_smm_36_community_rating`, `20261027130000_smm_36_rating_history`, `20261101120000_smm_40_analytics_indexes`).
- **Bugs / Improvements Needed:**
  - Until `npx prisma migrate deploy` is executed, `POST /ratings` and `GET /ratings/*` fail at runtime because `MatchFeedback` and `PlayerRating` tables do not yet exist in the local DB container.
- **API / DB Integration Needed:** Run `npx prisma migrate deploy` and `npx prisma generate` (`TASK-M2-01`).
- **Exact Files / Modules:** `backend/prisma/migrations/`, `backend/src/ratings/ratings.service.ts`, `mobile/lib/features/feedback/screens/live_match_feedback_screen.dart`.
- **Tests Required:** Integration test for `POST /ratings` (verifying `reliabilityScore` updates, duplicate feedback is rejected with `409`, and technical `Skill` axes remain untouched).

### Feature 11: Owner Dashboard (Statistics, Charts, 2D Court Schedule, Booking Management)
- **Current Status:** `PARTIAL` (**Priority: P0**)
- **Working in Code:**
  - Backend `AnalyticsController` & `RevenueAnalyticsController` (`GET /analytics/summary`, `/revenue`, `/bookings-by-slot`, `/court-utilization`, `/booking-status`, `/peak-hours`) and `GET /bookings/owner`.
  - Mobile `DashboardRepository` (`mobile/lib/features/dashboard/data/dashboard_repository.dart`) fetches all 6 analytics endpoints + owner bookings in parallel.
  - `DashboardScheduleGrid` widget (`mobile/lib/features/dashboard/widgets/dashboard_widgets.dart:245-395`) already exists.
- **What Is Missing:**
  - Live data binding for the 2D `DashboardScheduleGrid` (`Court x TimeSlot`) when `DashboardScreen` is in live mode (`!data.preview`).
- **Bugs / Improvements Needed:**
  - In `mobile/lib/features/dashboard/screens/dashboard_screen.dart:1383-1400`, when `!data.preview` is active, the Owner Schedule tab skips `DashboardScheduleGrid` and only renders a flat vertical list of `_bookingCard(b)`. Transform live `data.ownerBookings` and facility courts into `CourtColumn` / `ScheduleCellData` so the 2D `Court x TimeSlot` matrix renders in live mode and tapping a booked cell opens `OwnerBookingDetailScreen`.
- **API / DB Integration Needed:** Map live `OwnerBookingRecord` items and facility courts into `DashboardScheduleGrid` inside `dashboard_screen.dart`.
- **Exact Files / Modules:** `mobile/lib/features/dashboard/screens/dashboard_screen.dart`, `mobile/lib/features/dashboard/widgets/dashboard_widgets.dart`.
- **Tests Required:** Simulator E2E test logging in as `owner1@smatch.vn`, inspecting KPI charts, switching to the Schedule tab, and verifying a newly created Player booking appears in the 2D `Court x TimeSlot` grid.

### Feature 12: Finance (Payment Confirmation, Paid/Unpaid Status, Actual Revenue)
- **Current Status:** `MISSING / PARTIAL` (**Priority: P1**)
- **Working in Code:**
  - `grossBookedRevenue` is calculated accurately from non-cancelled bookings in `RevenueAnalyticsService` (`backend/src/analytics/revenue-analytics.service.ts`).
- **What Is Missing:**
  - `PaymentStatus` enum (`UNPAID`, `PAID`, `PENDING`, `CANCELLED`), `Booking.paymentStatus` (default `UNPAID`), and `Booking.paidAt` in `backend/prisma/schema.prisma`.
  - `PATCH /bookings/:id/payment-status` endpoint in `BookingsController` / `BookingsService` (restricted to the facility's `COURT_OWNER` or `ADMIN`).
  - Real `collectedRevenue` (`paymentStatus = PAID`) and `outstandingRevenue` (`paymentStatus = UNPAID`) sums in `RevenueAnalyticsService`.
  - Owner UI badge (`PAID` / `UNPAID`) and **"Mark as Paid (Pay at Court)"** button in `OwnerBookingDetailScreen` (`dashboard_screen.dart:1750-1915`).
- **Bugs / Improvements Needed:**
  - `RevenueAnalyticsService` (`revenue-analytics.service.ts:95,164`) currently returns `collectedRevenue: null` with a note that payment status is not tracked in schema.
- **API / DB Integration Needed:** Add `paymentStatus` & `paidAt` to `Booking`, expose `PATCH /bookings/:id/payment-status`, compute `collectedRevenue` in `GET /analytics/revenue` & `GET /analytics/summary`, and wire the Owner confirmation button in Flutter.
- **Exact Files / Modules:** `backend/prisma/schema.prisma`, `backend/src/bookings/bookings.controller.ts`, `backend/src/bookings/bookings.service.ts`, `backend/src/analytics/revenue-analytics.service.ts`, `mobile/lib/features/dashboard/screens/dashboard_screen.dart`, `mobile/lib/features/dashboard/data/dashboard_repository.dart`.
- **Tests Required:** Integration test verifying Owner marks booking `PAID` -> `GET /analytics/revenue` increases `collectedRevenue` and decreases `outstandingRevenue`, and a non-owner receives `403 Forbidden`.

### Feature 13: Smash Scot AI (Real Backend Data, Tools, Role Permissions, Useful Responses)
- **Current Status:** `DEMO` (**Priority: P1**)
- **Working in Code:**
  - Draggable `SmashScot` floating button and `SmashScotChat` modal sheet UI in `mobile/lib/features/player_experience/widgets/smash_scot.dart`.
- **What Is Missing:**
  - Backend `AiModule` (`POST /ai/chat`) with JWT + role-guarded server-side data tools (`PLAYER`: query real Da Nang facilities/courts, open matches, matchmaking recommendations, and own bookings; `COURT_OWNER`: query own facility utilization, bookings, and revenue summary; `ADMIN`: system-wide overview).
  - Live HTTP client in `SmashScotChat` calling `POST /ai/chat` and rendering structured action cards.
  - Mounting `SmashScot` overlay on `DashboardScreen` for Court Owners/Admins.
- **Bugs / Improvements Needed:**
  - `SmashScotChat.send` (`smash_scot.dart:117-135`) currently uses hardcoded English substring checks (`contains('court')`, `contains('player')`, `contains('review')`) against `DemoCatalog`.
- **API / DB Integration Needed:** Create `backend/src/ai/ai.module.ts`, `ai.controller.ts`, `ai.service.ts` calling Prisma services with strict RBAC (`req.user.userId`, `req.user.role`), and connect `SmashScotChat` in Flutter.
- **Exact Files / Modules:** `backend/src/ai/ai.module.ts`, `backend/src/ai/ai.controller.ts`, `backend/src/ai/ai.service.ts`, `mobile/lib/features/player_experience/widgets/smash_scot.dart`, `mobile/lib/features/dashboard/screens/dashboard_screen.dart`.
- **Tests Required:** Integration test verifying a `PLAYER` token cannot query Owner revenue via `POST /ai/chat`; Simulator E2E test asking Smash Scot for available courts in Hai Chau (as Player) and today's revenue (as Owner).

### Feature 14: Coach/Courses & Shop Directory (Existing Demo Content vs Real Data)
- **Current Status:** `DEMO` (**Priority: P2**)
- **Working in Code:**
  - `LearningScreen`, `LearningDetailScreen`, `ShopDirectoryScreen`, and `ShopDetailScreen` in `mobile/lib/features/player_experience/screens/` render Da Nang coaches, courses, and badminton shops with external call/website/map links via `url_launcher` (strictly directory-only, no cart/checkout).
- **What Is Missing:**
  - Read-only `Coach`, `Course`, and `ShopDirectoryEntry` Prisma models, seed records, `GET /catalog/courses` & `GET /catalog/shops` endpoints, and Mobile repository fetch with fallback to `DemoCatalog`.
- **Bugs / Improvements Needed:**
  - Currently 100% hardcoded in `DemoCatalog` (`demo_catalog.dart`). Implementing read-only DB/API catalog endpoints removes the remaining `DemoNotice` banners on Learning and Shop tabs.
- **API / DB Integration Needed:** Add read-only catalog tables to `schema.prisma`, seed Da Nang entries in `seed.ts`, expose `GET /catalog/courses` and `GET /catalog/shops`, and fetch them in `player_experience`.
- **Exact Files / Modules:** `backend/prisma/schema.prisma`, `backend/prisma/seed.ts`, `backend/src/catalog/`, `mobile/lib/features/player_experience/screens/learning_screens.dart`, `shop_screens.dart`.
- **Tests Required:** API test for `GET /catalog/courses` and `GET /catalog/shops`; UI check confirming zero cart/order/checkout widgets exist.

### Feature 15: Overall Flutter UI/UX (Navigation Consistency, Loading, Empty/Error States, Responsive Layouts)
- **Current Status:** `WORKING / PARTIAL` (**Priority: P1**)
- **Working in Code:**
  - Consistent design tokens (`AppColors`, `DashboardPalette`), motion tokens (`AppMotion`), bottom navigation (`PlayerBottomNavigation`), and loading/error states on Map, Booking, Dashboard, and Feedback screens.
- **What Is Missing:**
  - Removing `DemoNotice` banners on screens once wired to live Backend APIs (`PlayerHomeScreen`, `ExploreCourtsScreen`, `ExperienceSearchScreen`).
- **Bugs / Improvements Needed:**
  - Ensure newly wired screens (`MatchListScreen`, `MatchInvitationsScreen`, `MatchJoinRequestsScreen`, `SkillAssessmentScreen`, `SmashScotChat`) display clear loading indicators, empty states, and retry buttons on network failure.
- **Exact Files / Modules:** `mobile/lib/features/player_experience/screens/player_home_screen.dart`, `courts_screens.dart`, `mobile/lib/features/match/screens/`.
- **Tests Required:** `flutter analyze` with zero errors and Simulator walk-through across all tabs.

---

## 3. Tests Still Required

### A. Unit Tests (Fast, Isolated, No Shared DB Mutation)
1. **FacilitiesService Unit Suite (`backend/src/facilities/facilities.service.spec.ts`):**
   - Replace the `0-byte` empty file with tests for `createFacility`, `findAll`, `findMyFacilities`, `updateFacility` (including `ForbiddenException` when non-owner edits), `addCourt`, and `deleteCourt`.
2. **FastAPI 5-Factor Scoring Suite (`matchmaking/tests/test_matcher.py` & `test_api.py`):**
   - Install `numpy` in `matchmaking/.venv` (`pip install -r requirements.txt`).
   - Test `POST /api/v1/match` with known candidate vectors: verify `match_score` equals $0.35 S_{\text{skill}} + 0.25 S_{\text{time}} + 0.20 S_{\text{distance}} + 0.10 S_{\text{style}} + 0.10 S_{\text{reliability}}$, verify no hardcoded `+ 0.45` exists, and verify all 5 breakdown keys (`skill_score`, `time_score`, `distance_score`, `style_score`, `reliability_score`) are returned in `[0, 100]`.
3. **NestJS `FastApiClient` & `MatchmakingService` Unit Tests (`backend/src/matchmaking/fastapi.client.spec.ts`):**
   - Update mock responses to validate and preserve all 5 breakdown keys and verify fallback sorting when FastAPI is unreachable.
4. **Candidates Privacy & Availability Unit Test (`backend/src/candidates/candidates.service.spec.ts`):**
   - Verify `findNearby()` never serializes raw `latitude` or `longitude` of other players and accurately computes `availableNow: boolean`.
5. **Skill Assessment vs Post-Match Rating Separation Test (`backend/src/players/players.service.spec.ts` & `backend/src/ratings/ratings.service.spec.ts`):**
   - Verify `PUT /players/profile/me/skill` validates `0..100` for all 6 axes and updates `PlayerProfile.skillScore`, while `POST /ratings` updates `PlayerRating` and `PlayerProfile.reliabilityScore` without modifying `Skill`.

### B. API / Database Integration Tests (Against Isolated Test Schema `DATABASE_URL` with `?schema=test_integration`)
1. **Workflow 1 — Registration, Login & Role Permissions (`auth.e2e-spec.ts`):**
   - Register/login as `PLAYER` and `COURT_OWNER`, rotate refresh tokens via `POST /auth/refresh`, and verify `RolesGuard` blocks `PLAYER` from `POST /facilities`, `GET /bookings/owner`, and `PATCH /bookings/:id/payment-status` (`403 Forbidden`).
2. **Workflow 2 — Da Nang Facilities, Courts & Slot Availability (`facilities-availability.e2e-spec.ts`):**
   - Verify `GET /facilities` returns all 10 seeded Da Nang facilities with 2–4 courts each and `GET /facilities/:id/courts/:courtId/time-slots/availability?date=YYYY-MM-DD` returns accurate slot pricing and availability.
3. **Workflow 4 — Booking Creation, Concurrency Lock, History & Cancellation (`bookings-concurrency.e2e-spec.ts`):**
   - Fire 2 simultaneous `POST /bookings` requests (`Promise.all`) for the same `courtId`, `bookingDate`, and overlapping `timeSlotIds`. Assert exactly one returns `201 Created` and the second returns `409 Conflict` via `SELECT ... FOR UPDATE`.
   - Verify `GET /bookings/my`, `GET /bookings/owner`, and `PATCH /bookings/:id/cancel` (freeing the slots for re-booking).
4. **Workflow 5 — Open & Private Match Creation, Invitations, Requests, Approvals & Completion (`matches-lifecycle.e2e-spec.ts`):**
   - Host creates an `OPEN` match (`POST /matches`) -> Player B sends `POST /matches/:id/join-request` -> Host approves via `PATCH /matches/:id/requests/:userId/approve`.
   - Host creates a `PRIVATE` match -> invites Player C via `POST /matches/:id/invite` -> Player C lists `GET /matches/my-invitations` and accepts via `PATCH /matches/:id/invitations/accept`.
   - Host completes match via `PATCH /matches/:id/complete`.
5. **Workflow 6 & 7 — 5-Factor Matchmaking & Post-Match Feedback (`matchmaking-ratings.e2e-spec.ts`):**
   - Call `POST /matchmaking/recommend` -> verify 5-factor breakdown response.
   - Submit post-match feedback via `POST /ratings` -> verify `GET /ratings/users/:id/summary` and `/history` update `reliabilityScore` while `GET /players/profile/me` 6-axis `skill` remains unchanged; verify duplicate feedback returns `409 Conflict`.
6. **Workflow 8 & 9 — Owner Analytics & Finance Payment Status (`finance-analytics.e2e-spec.ts`):**
   - Owner calls `PATCH /bookings/:id/payment-status` (`{ paymentStatus: 'PAID' }`) -> verify `GET /analytics/revenue` and `GET /analytics/summary` reflect the updated `collectedRevenue` and `outstandingRevenue`.
7. **Workflow 10 — Smash Scot AI Role Guard Test (`ai-chat.e2e-spec.ts`):**
   - Verify `POST /ai/chat` with `PLAYER` token returns real Da Nang courts/matches and denies Owner revenue queries; verify `COURT_OWNER` token returns only that owner's facility revenue/utilization.

### C. Flutter Simulator End-to-End Tests (10 Prioritized Workflows)
Run on iOS Simulator / Android Emulator against local Docker PostgreSQL + NestJS (`:3000`) + FastAPI (`:8000`):
1. **E2E-01 (Auth & Roles):** Sign in as `player1@smatch.vn` (`PLAYER`) and `owner1@smatch.vn` (`COURT_OWNER`); verify role routing and session persistence across app restart; verify Google Sign-In flow.
2. **E2E-02 (Player Home, Explore & Search -> Live Courts):** From `PlayerHomeScreen`, search/filter Da Nang facilities, tap a facility card, and verify it opens live `BookingFacilityScheduleScreen` (no negative demo IDs).
3. **E2E-03 (MapLibre -> Court Detail -> Live Booking):** Open `FindCourtsMapScreen`, tap a Da Nang facility marker, inspect `CourtPreviewScreen`, select a court & continuous time slots, confirm booking, and verify PostgreSQL persistence.
4. **E2E-04 (Booking History & Live Cancellation):** Open `BookingHistoryScreen`, open the newly created booking in `BookingDetailScreen`, tap **"Cancel Booking"**, and verify status changes to `CANCELLED` and slots become `AVAILABLE` again.
5. **E2E-05 (Open & Private Match Full Lifecycle):** Host creates an Open Match and a Private Match from `CreateMatchScreen`; second player requests to join the Open Match and accepts the Private Match invitation in `MatchInvitationsScreen`; Host approves the join request in `MatchJoinRequestsScreen` and marks the match `COMPLETED`.
6. **E2E-06 (Find Players & 5-Factor Matchmaking):** Open `FindPlayersMapScreen` (test distance, skill level, and `"Available Now"` filters), open Matchmaking recommendations, inspect the 5-factor breakdown card, and invite a recommended player to an active match.
7. **E2E-07 (6-Axis Skill Radar & Post-Match Feedback):** Update the 6 skill sliders in `SkillAssessmentScreen` and verify `ProfileSkillRadar` redraws dynamically; submit post-match feedback in `LiveMatchFeedbackScreen` and verify `RatingHistoryScreen` updates reliability without altering the 6 skill axes.
8. **E2E-08 (Owner Dashboard & 2D Court Schedule):** Log in as `owner1@smatch.vn`, verify KPI cards and revenue/utilization charts, open the Schedule tab, and verify the live 2D `Court x TimeSlot` grid (`DashboardScheduleGrid`) shows the player's booking.
9. **E2E-09 (Owner Finance Payment Confirmation):** In `DashboardScreen`, tap an unpaid booking in the 2D schedule grid to open `OwnerBookingDetailScreen`, tap **"Mark as Paid"**, and verify the badge changes to `PAID` and collected revenue updates on the dashboard.
10. **E2E-10 (Smash Scot AI Assistant):** Open `SmashScot` as a Player to ask for available courts in Hai Chau, and as a Court Owner on `DashboardScreen` to ask for facility revenue and utilization.

---

## 4. Member 1 Checklist — MOBILE (Flutter UI, API Integration, MapLibre, Schedule, Skill Radar, Smash Scot UI)

> **Backlog Streamlining Note:** `TASK-OPT-02` (SMS/Forgot Password demo cleanup) is folded directly into `TASK-M1-06B` as a 5-line UI label update in `login_screen.dart` / `forgot_password_screen.dart` so zero unnecessary OTP backend code is written.

- [ ] **TASK-M1-01: Connect Player Home, Explore Courts & Search to Live `GET /facilities`** (Priority: **P0**)
  - **What to implement/fix:** Replace `demoCatalogProvider` court lists in `PlayerHomeScreen`, `ExploreCourtsScreen`, and `ExperienceSearchScreen` with `FacilityApiService.getFacilities()`. Route court card taps to `BookingFacilityScheduleScreen(facilityId: facility.id)` and route the `"Explore Map"` button on `PlayerHomeScreen:125` to `FindCourtsMapScreen`.
  - **Specific files/modules:** `mobile/lib/features/player_experience/screens/player_home_screen.dart`, `mobile/lib/features/player_experience/screens/courts_screens.dart`, `mobile/lib/features/facility/services/facility_api_service.dart`.
  - **Dependencies:** `TASK-M2-02` (10 Da Nang facilities seeded).
  - **How to test:** Launch app as Player, tap facility cards from Home, Explore, and Search, and complete a booking.
  - **Completion criteria:** Zero negative facility IDs (`-1001`..`-1010`) or `DemoCourtDetailScreen` navigation remain in live mode.

- [ ] **TASK-M1-02: Wire Live Booking Cancellation in `BookingDetailScreen`** (Priority: **P0**)
  - **What to implement/fix:** Update the `"Cancel Booking"` button handler in `BookingDetailScreen` (`booking_detail_screen.dart:204-221`) so that when viewing a live booking, it calls `LiveBookingService.instance.cancelBooking(booking.id)` (`PATCH /bookings/:id/cancel`), handles loading/error states, and refreshes `BookingHistoryScreen`.
  - **Specific files/modules:** `mobile/lib/features/booking/screens/booking_detail_screen.dart`, `mobile/lib/features/booking/services/live_booking_service.dart`, `mobile/lib/features/booking/screens/booking_history_screen.dart`.
  - **Dependencies:** None (Backend `PATCH /bookings/:id/cancel` already works).
  - **How to test:** Create a booking in Simulator, open it from Booking History, tap `"Cancel Booking"`, and verify status becomes `CANCELLED` in DB and UI.
  - **Completion criteria:** Cancelling a booking from `BookingDetailScreen` persists `status = CANCELLED` in PostgreSQL and frees the court slots.

- [ ] **TASK-M1-03: Replace `MatchUiStore` with Live `/matches` APIs & Enable Player Invite Flow** (Priority: **P0**)
  - **What to implement/fix:** Create `MatchApiService` in `mobile/lib/features/match/services/match_api_service.dart` and connect `CreateMatchScreen` (`POST /matches` / `POST /bookings/:id/open-match`), `MatchListScreen` (`GET /matches/open` & `GET /matches/my`), `MatchDetailOpenScreen` (`GET /matches/:id`, `POST /matches/:id/join-request`, `PATCH /open-matches/:id/leave`), `MatchJoinRequestsScreen` (`PATCH /matches/:id/requests/:userId/approve|reject`), `MatchInvitationsScreen` (`GET /matches/my-invitations`, `PATCH /matches/:id/invitations/accept|reject`), `MatchParticipantListScreen`, and the `"Invite to Match"` button in `RecommendedPlayerDetailScreen` (`POST /matches/:id/invite`).
  - **Specific files/modules:** `mobile/lib/features/match/services/match_api_service.dart`, `mobile/lib/features/match/screens/create_match_screen.dart`, `match_list_screen.dart`, `match_detail_open_screen.dart`, `match_join_requests_screen.dart`, `match_invitations_screen.dart`, `match_participant_list_screen.dart`, `mobile/lib/features/recommendation/screens/recommended_player_detail_screen.dart`.
  - **Dependencies:** `TASK-M3-01` (`GET /matches/my-invitations` & `GET /matches/my`).
  - **How to test:** Run two Simulator sessions (Host & Player B) through Open Match join request/approval and Private Match invitation/acceptance.
  - **Completion criteria:** All 6 match screens and player invitations persist to PostgreSQL `Match`, `MatchPlayer`, and `MatchInvitation` tables.

- [ ] **TASK-M1-04: Render Live 2D `Court x TimeSlot` Grid (`DashboardScheduleGrid`) & Owner Payment Action** (Priority: **P0**)
  - **What to implement/fix:**
    1. In `DashboardScreen` (`dashboard_screen.dart:1383-1400`), transform live `data.ownerBookings` and facility courts into `List<CourtColumn>` and render `DashboardScheduleGrid` above the booking list when `!data.preview`.
    2. In `OwnerBookingDetailScreen` (`dashboard_screen.dart:1750-1915`), display the booking's `paymentStatus` badge (`PAID` / `UNPAID`) and add a **"Mark as Paid (Pay at Court)"** button calling `PATCH /bookings/:id/payment-status`.
  - **Specific files/modules:** `mobile/lib/features/dashboard/screens/dashboard_screen.dart`, `mobile/lib/features/dashboard/widgets/dashboard_widgets.dart`, `mobile/lib/features/dashboard/data/dashboard_repository.dart`.
  - **Dependencies:** `TASK-M3-03` (`PATCH /bookings/:id/payment-status` for the payment button; the 2D grid itself has zero external dependencies).
  - **How to test:** Log in as `owner1@smatch.vn`, open Schedule tab, verify the 2D `Court x TimeSlot` matrix renders live bookings, tap a cell, and mark it `PAID`.
  - **Completion criteria:** Live Owner Schedule displays the interactive 2D `Court x TimeSlot` grid and updates `paymentStatus` + `collectedRevenue`.

- [ ] **TASK-M1-05: Enable Live `"Available Now"` Filter & Location Update in `FindPlayersMapScreen`** (Priority: **P1**)
  - **What to implement/fix:** Map `availableNow` from `GET /candidates/nearby` in `ExplorationDataRepository` (`exploration_data.dart`), enable the `"Available Now"` filter toggle in `FindPlayersMapScreen` (`find_players_map_screen.dart:55-61,232-244`), and call `PATCH /candidates/me/location` when updating player search origin.
  - **Specific files/modules:** `mobile/lib/features/court_map/data/exploration_data.dart`, `mobile/lib/features/court_map/screens/find_players_map_screen.dart`, `mobile/lib/features/court_map/widgets/player_discovery_overlay.dart`.
  - **Dependencies:** `TASK-M3-02` (`availableNow` field in `GET /candidates/nearby`).
  - **How to test:** Toggle `"Available Now"`, distance slider, and skill chips on `FindPlayersMapScreen` and verify marker filtering.
  - **Completion criteria:** `"Available Now"` filter chip works with live Backend data and player privacy is preserved.

- [ ] **TASK-M1-06A: Build Dynamic 6-Axis `CustomPainter` Radar Chart & Connect `SkillAssessmentScreen`** (Priority: **P1**)
  - **What to implement/fix:**
    1. Replace static SVG rendering in `ProfileSkillRadar` (`profile_skill_radar.dart:53-111`) with a `CustomPainter` that draws the 6-axis concentric grid and plots the player's `smash`, `defense`, `netPlay`, `stamina`, `footwork`, and `serve` values (`0..100`).
    2. Connect `SkillAssessmentScreen` (`skill_assessment_screen.dart:242-310`) to `GET /players/profile/me` and `PUT /players/profile/me/skill`.
  - **Specific files/modules:** `mobile/lib/features/auth/widgets/profile_skill_radar.dart`, `mobile/lib/features/auth/screens/skill_assessment_screen.dart`, `mobile/lib/features/auth/screens/profile_screen.dart`, `mobile/lib/features/auth/services/player_profile_service.dart`.
  - **Dependencies:** `TASK-M3-04` (`PUT /players/profile/me/skill` and `include: { skill: true }`).
  - **How to test:** Adjust the 6 sliders in `SkillAssessmentScreen`, tap Save, and verify `ProfileScreen` radar chart updates and persists across app restarts.
  - **Completion criteria:** Radar polygon dynamically reflects the 6 DB-persisted skill axes.

- [ ] **TASK-M1-06B: Integrate `google_sign_in` SDK & Clarify Demo Auth Controls** (Priority: **P1**)
  - **What to implement/fix:** Add `google_sign_in` to `mobile/pubspec.yaml`, wire the Google button in `LoginScreen` (`login_screen.dart:181-185`) to obtain a Google `idToken` and send it to `POST /auth/google` in `AuthService`, and label the SMS/Forgot Password demo screens clearly as preview-only.
  - **Specific files/modules:** `mobile/pubspec.yaml`, `mobile/lib/features/auth/screens/login_screen.dart`, `mobile/lib/features/auth/screens/forgot_password_screen.dart`, `mobile/lib/core/services/auth_service.dart`.
  - **Dependencies:** `TASK-M3-05` (`POST /auth/google`).
  - **How to test:** Tap `"Continue with Google"` on Simulator, complete sign-in, and verify JWT session creation and navigation.
  - **Completion criteria:** Google Sign-In authenticates against NestJS and stores valid access/refresh tokens.

- [ ] **TASK-M1-07: Connect `SmashScotChat` to `POST /ai/chat` & Mount on `DashboardScreen`** (Priority: **P1**)
  - **What to implement/fix:** Replace hardcoded keyword matching in `SmashScotChat.send` (`smash_scot.dart:117-135`) with an authenticated call to `POST /ai/chat`, render returned court/match/analytics data, and mount the draggable `SmashScot` widget on `DashboardScreen` for Court Owners/Admins.
  - **Specific files/modules:** `mobile/lib/features/player_experience/widgets/smash_scot.dart`, `mobile/lib/features/dashboard/screens/dashboard_screen.dart`.
  - **Dependencies:** `TASK-M3-06` (`POST /ai/chat`).
  - **How to test:** Query Smash Scot as Player (available courts/matches) and as Court Owner (facility revenue/utilization).
  - **Completion criteria:** Smash Scot returns live role-scoped PostgreSQL data for both Players and Court Owners.

- [ ] **TASK-M1-08: Display 5-Factor Matchmaking Breakdown & Connect Optional Catalog API** (Priority: **P1 / P2**)
  - **What to implement/fix:** Update `ApiRecommendationRepository` and recommendation cards (`mobile/lib/features/recommendation/`) to display all 5 breakdown scores (`skill`, `time`, `distance`, `style`, `reliability`) returned by `POST /matchmaking/recommend`. If `GET /catalog/*` is enabled (`TASK-OPT-01`), fetch courses and shops from API with fallback to `DemoCatalog`.
  - **Specific files/modules:** `mobile/lib/features/recommendation/data/recommendation_repository.dart`, `mobile/lib/features/recommendation/screens/recommended_players_screen.dart`, `mobile/lib/features/player_experience/screens/learning_screens.dart`, `shop_screens.dart`.
  - **Dependencies:** `TASK-M4-01`, `TASK-M3-07`.
  - **How to test:** Open Matchmaking recommendations and verify all 5 factor bars/scores render accurately.
  - **Completion criteria:** All 5 matchmaking factors are visible in the UI and match FastAPI output.

---

## 5. Member 2 Checklist — DATABASE (Prisma Schema, Migrations, Seed Data, Integrity, Test Isolation)

> **Backlog Streamlining Note:** `TASK-M2-04` (`Booking.paymentStatus` schema addition) and `TASK-M2-05` (optional `Coach`/`Course`/`ShopDirectoryEntry` catalog models) are merged into a single schema migration task (`TASK-M2-03`) so the team only needs to generate and apply **one** new Prisma migration after deploying the 4 existing pending migrations.

- [ ] **TASK-M2-01: Apply the 4 Pending Prisma Migrations & Regenerate Prisma Client** (Priority: **P0**)
  - **What to implement/fix:** Run `npx prisma migrate deploy` and `npx prisma generate` in `backend/` to apply the 4 unapplied migrations (`20261027120000_add_match_feedback`, `20261027120000_smm_36_community_rating`, `20261027130000_smm_36_rating_history`, `20261101120000_smm_40_analytics_indexes`).
  - **Specific files/modules:** `backend/prisma/migrations/`, `backend/prisma/schema.prisma`.
  - **Dependencies:** None (must be executed **first**).
  - **How to test:** Run `npx prisma migrate status` and verify `Database schema is up to date!`.
  - **Completion criteria:** `MatchFeedback`, `PlayerRating`, and analytics composite indexes exist in PostgreSQL and `POST /ratings` succeeds.

- [ ] **TASK-M2-02: Expand `backend/prisma/seed.ts` to 10 Da Nang Facilities (20–40 Courts) & Realistic Demo Data** (Priority: **P0**)
  - **What to implement/fix:** Update `backend/prisma/seed.ts` using idempotent natural keys (`ownerId + facilityName` and `facilityId + courtName`—never hardcoded `id: 1..10`) to seed:
    - **2 Court Owners:** `owner1@smatch.vn` (6 facilities) and `owner2@smatch.vn` (4 facilities), plus `admin@smatch.vn`.
    - **10 Da Nang Facilities** with real Da Nang coordinates (`16.00..16.09°N, 108.15..108.25°E` across Hai Chau, Son Tra, Ngu Hanh Son, Thanh Khe, Cam Le, Lien Chieu).
    - **2–4 Courts per facility (20–40 Courts total)**, Operating Hours (`06:00–22:00` for `dayOfWeek` `0..6`), and 16 hourly `TimeSlot`s per court (`60,000–120,000 VND`).
    - **12 Players** (`player1@smatch.vn`..`player12@smatch.vn`) with `PlayerProfile`, 6-axis `Skill` (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve`), `Availability` windows, historical `Booking`s (`PAID` & `UNPAID`), `Match`es (`OPEN`, `PRIVATE`, `COMPLETED`), and `PlayerRating` records.
  - **Specific files/modules:** `backend/prisma/seed.ts`.
  - **Dependencies:** `TASK-M2-01`.
  - **How to test:** Run `npx prisma db seed` twice consecutively and verify row counts remain exact (`10` Facilities, `20–40` Courts, `12` Players, `0` duplicate errors).
  - **Completion criteria:** `GET /facilities` returns 10 Da Nang facilities with 2–4 courts each and idempotent re-seeding passes.

- [ ] **TASK-M2-03: Add `Booking.paymentStatus` (`PaymentStatus` Enum) & Read-Only Catalog Models in One Migration** (Priority: **P1**)
  - **What to implement/fix:**
    1. In `backend/prisma/schema.prisma`, add `enum PaymentStatus { UNPAID PAID PENDING CANCELLED }` and add `paymentStatus PaymentStatus @default(UNPAID)` + `paidAt DateTime?` to `Booking` (with index `@@index([courtId, bookingDate, paymentStatus])`).
    2. Add read-only `Coach`, `Course`, and `ShopDirectoryEntry` models (no cart/order tables) if the team includes `TASK-OPT-01`.
    3. Run `npx prisma migrate dev --name add_booking_payment_status_and_catalog`.
  - **Specific files/modules:** `backend/prisma/schema.prisma`, `backend/prisma/migrations/`.
  - **Dependencies:** `TASK-M2-01`.
  - **How to test:** Inspect generated SQL migration, run `npx prisma migrate status`, and verify existing bookings default to `UNPAID`.
  - **Completion criteria:** `Booking.paymentStatus` and `Booking.paidAt` are available in `@prisma/client` for Member 3's Finance endpoints.

- [ ] **TASK-M2-04: Configure Isolated Test Schema (`?schema=test_integration`) & Verify Concurrency Locking** (Priority: **P0**)
  - **What to implement/fix:** Create `backend/.env.test` pointing `DATABASE_URL` to `?schema=test_integration` and add a pre-test setup helper in `backend/test/` so integration tests run `prisma migrate deploy` against `test_integration` without mutating the development `public` schema. Verify `SELECT ... FOR UPDATE` row locking on `Court` and `@@unique([matchId, fromUserId, toUserId])` on `PlayerRating`.
  - **Specific files/modules:** `backend/.env.test`, `backend/package.json`, `backend/test/jest-e2e.json`.
  - **Dependencies:** `TASK-M2-01`, `TASK-M2-03`.
  - **How to test:** Run `npm run test:e2e` and verify `public` schema row counts in the main dev database are untouched.
  - **Completion criteria:** Integration tests execute cleanly in `test_integration` with zero side effects on demo data.

---

## 6. Member 3 Checklist — BACKEND (NestJS APIs, Auth, Match/Invitation, Privacy, Finance, AI Tools, RBAC)

- [ ] **TASK-M3-01: Add `GET /matches/my-invitations` and `GET /matches/my` to `MatchesController`** (Priority: **P0**)
  - **What to implement/fix:**
    1. Add `@Get('my-invitations')` in `backend/src/matches/matches.controller.ts` returning matches (both `PRIVATE` and `OPEN`) where the authenticated user has a `MatchInvitation` (`status: INVITED`), including host profile, facility, court, and booking slot details.
    2. Add `@Get('my')` returning matches where `hostId === req.user.userId` or the user is in `MatchPlayer` (`ACCEPTED` / `REQUESTED`), so the Host can view pending join requests and participants can view their upcoming/completed matches.
  - **Specific files/modules:** `backend/src/matches/matches.controller.ts`, `backend/src/matches/matches.service.ts`.
  - **Dependencies:** `TASK-M2-01`.
  - **How to test:** Create a `PRIVATE` match as Host, invite Player B via `POST /matches/:id/invite`, and verify Player B sees it in `GET /matches/my-invitations`.
  - **Completion criteria:** Both endpoints return complete match + facility + participant DTOs protected by `JwtAuthGuard`.

- [ ] **TASK-M3-02: Strip Raw Coordinates & Add `availableNow` in `CandidatesService.findNearby`** (Priority: **P0**)
  - **What to implement/fix:** In `backend/src/candidates/candidates.service.ts:95-128`, remove raw `latitude` and `longitude` from the returned candidate objects (keep `distanceKm` rounded to 1 decimal place and coarse district/area label), and compute `availableNow: boolean` by checking whether the candidate has an `Availability` window matching the current day of week and time in `UTC+7`.
  - **Specific files/modules:** `backend/src/candidates/candidates.service.ts`, `backend/src/candidates/candidates.controller.ts`.
  - **Dependencies:** None.
  - **How to test:** Call `GET /candidates/nearby?lat=16.0678&lng=108.2208&radiusKm=10` and assert every item has `distanceKm` and `availableNow` (`true`/`false`), and `latitude`/`longitude` are `undefined`.
  - **Completion criteria:** Zero raw GPS coordinates of other players are leaked over HTTP, and `availableNow` is returned for Mobile filtering.

- [ ] **TASK-M3-03: Implement `PATCH /bookings/:id/payment-status` & Real `collectedRevenue` in Analytics** (Priority: **P1**)
  - **What to implement/fix:**
    1. Add `@Patch(':id/payment-status')` (`@Roles('COURT_OWNER', 'ADMIN')`) in `backend/src/bookings/bookings.controller.ts` and `bookings.service.ts` to verify facility ownership and update `Booking.paymentStatus` (`PAID` / `UNPAID` / `CANCELLED`) and `Booking.paidAt`.
    2. Update `RevenueAnalyticsService` (`backend/src/analytics/revenue-analytics.service.ts:95,164`) to calculate real `collectedRevenue` (sum of `totalPrice` where `paymentStatus === 'PAID'` and `status !== 'CANCELLED'`) and `outstandingRevenue` (`paymentStatus === 'UNPAID'`).
    3. Include `paymentStatus` and `paidAt` in `GET /bookings/owner` and `GET /bookings/my` responses.
  - **Specific files/modules:** `backend/src/bookings/bookings.controller.ts`, `backend/src/bookings/bookings.service.ts`, `backend/src/bookings/dto/update-payment-status.dto.ts`, `backend/src/analytics/revenue-analytics.service.ts`.
  - **Dependencies:** `TASK-M2-03` (`Booking.paymentStatus` schema field).
  - **How to test:** Call `PATCH /bookings/:id/payment-status` with `{ "paymentStatus": "PAID" }` as Owner and verify `GET /analytics/revenue` returns the updated `collectedRevenue`.
  - **Completion criteria:** Owner payment confirmation persists to DB and `collectedRevenue` is no longer `null`.

- [ ] **TASK-M3-04: Expose 6-Axis `Skill` in `GET /players/profile/me` & Add `PUT /players/profile/me/skill`** (Priority: **P1**)
  - **What to implement/fix:**
    1. In `PlayersService.getMyProfile` (`backend/src/players/players.service.ts:10-20`), update `include: { playerProfile: { include: { skill: true } } }`.
    2. Add `@Put('profile/me/skill')` in `PlayersController` (`backend/src/players/players.controller.ts`) with a DTO validating `smash`, `defense`, `netPlay`, `stamina`, `footwork`, and `serve` (`@IsInt()`, `@Min(0)`, `@Max(100)`). Upsert the `Skill` record and update `PlayerProfile.skillScore` to the rounded average of the 6 axes.
  - **Specific files/modules:** `backend/src/players/players.controller.ts`, `backend/src/players/players.service.ts`, `backend/src/players/dto/update-skill.dto.ts`.
  - **Dependencies:** None (`Skill` table already exists in Prisma).
  - **How to test:** Call `PUT /players/profile/me/skill` with 6 integers, then call `GET /players/profile/me` and verify `playerProfile.skill` matches.
  - **Completion criteria:** All 6 skill axes are returned on profile fetch and updatable via `PUT /players/profile/me/skill`.

- [ ] **TASK-M3-05: Implement `POST /auth/google` OAuth Verification in `AuthController` / `AuthService`** (Priority: **P1**)
  - **What to implement/fix:** Add `@Post('google')` to `backend/src/auth/auth.controller.ts` accepting `{ idToken: string }`. Verify the Google ID token via `google-auth-library` (or Google tokeninfo verification), find or create the `User` (`role: PLAYER` by default for new users, preserving existing role for returning users), create a `RefreshSession`, and return `{ accessToken, refreshToken, user }`.
  - **Specific files/modules:** `backend/src/auth/auth.controller.ts`, `backend/src/auth/auth.service.ts`, `backend/src/auth/dto/google-login.dto.ts`.
  - **Dependencies:** None.
  - **How to test:** Unit test `AuthService.googleLogin` with valid/invalid tokens and E2E test with Mobile (`TASK-M1-06B`).
  - **Completion criteria:** `POST /auth/google` issues standard JWT access + refresh tokens backed by `RefreshSession`.

- [ ] **TASK-M3-06: Implement Role-Guarded Smash Scot AI Endpoint (`POST /ai/chat`)** (Priority: **P1**)
  - **What to implement/fix:** Create `AiModule` (`backend/src/ai/ai.module.ts`, `ai.controller.ts`, `ai.service.ts`) protected by `JwtAuthGuard`. Implement role-scoped data tools querying Prisma (and Gemini API if `GEMINI_API_KEY` is set, with deterministic data-backed synthesis fallback so it never fails offline):
    - `PLAYER`: search real Da Nang facilities/courts, open matches, matchmaking recommendations, and the player's own bookings/ratings.
    - `COURT_OWNER`: query only facilities owned by `req.user.userId` (today's bookings, court utilization, gross vs collected revenue).
    - `ADMIN`: system-wide facility and booking metrics.
  - **Specific files/modules:** `backend/src/ai/ai.module.ts`, `backend/src/ai/ai.controller.ts`, `backend/src/ai/ai.service.ts`, `backend/src/app.module.ts`.
  - **Dependencies:** `TASK-M2-02`, `TASK-M3-03`.
  - **How to test:** Send `POST /ai/chat` with a `PLAYER` token asking for owner revenue (verify refusal/player-scoped response) and with a `COURT_OWNER` token asking for revenue (verify accurate numbers for their facilities only).
  - **Completion criteria:** `POST /ai/chat` returns real PostgreSQL data while strictly enforcing RBAC and tenant ownership.

- [ ] **TASK-M3-07: Update `FastApiClient` & `MatchmakingService` to Forward All 5 Breakdown Scores & Fix `facilities.service.spec.ts`** (Priority: **P0**)
  - **What to implement/fix:**
    1. In `backend/src/matchmaking/fastapi.client.ts:10,85-99`, update `FASTAPI_BREAKDOWN_KEYS` to `['skill_score', 'time_score', 'distance_score', 'style_score', 'reliability_score']` and include `breakdown` in the returned `FastApiMatchItem`.
    2. In `backend/src/matchmaking.service.ts`, forward the 5-factor `breakdown` in `POST /matchmaking/recommend` response items.
    3. Populate the `0-byte` `backend/src/facilities/facilities.service.spec.ts` with unit tests so `npm test` passes completely.
  - **Specific files/modules:** `backend/src/matchmaking/fastapi.client.ts`, `backend/src/matchmaking/fastapi.client.spec.ts`, `backend/src/matchmaking.service.ts`, `backend/src/facilities/facilities.service.spec.ts`.
  - **Dependencies:** `TASK-M4-01` (FastAPI 5-factor response).
  - **How to test:** Run `npm test` in `backend/` and verify all Jest suites pass (`0` failed suites).
  - **Completion criteria:** `POST /matchmaking/recommend` returns all 5 breakdown scores and `npm test` is 100% green.

---

## 7. Member 4 Checklist — MATCHMAKING (FastAPI, Five-Factor Ranking, Scoring Correctness, Python Testing)

- [ ] **TASK-M4-01: Wire Production `POST /api/v1/match` in `main.py` to 5-Factor `MatchmakingEngine` & Remove `+ 0.45`** (Priority: **P0**)
  - **What to implement/fix:**
    1. In `matchmaking/app/main.py:100-180`, remove the inline 2-factor calculation (`skill_similarity * 0.3 + (distance_score / 100.0) * 0.25 + 0.45`) and delegate `POST /api/v1/match` directly to `MatchmakingEngine` (`matchmaking/app/services/matcher.py`) using the 5 weights:
       $$\text{Score} = 0.35 S_{\text{skill}} + 0.25 S_{\text{time}} + 0.20 S_{\text{distance}} + 0.10 S_{\text{style}} + 0.10 S_{\text{reliability}}$$
    2. Return all 5 normalized sub-scores (`0..100`) in `breakdown`: `skill_score`, `time_score`, `distance_score`, `style_score`, and `reliability_score`, plus `match_score` (`0..100`) and `distance_km`.
  - **Specific files/modules:** `matchmaking/app/main.py`, `matchmaking/app/services/matcher.py`, `matchmaking/app/schemas.py`.
  - **Dependencies:** None.
  - **How to test:** Call `POST /api/v1/match` with sample candidate payloads and verify changing `available_time_slots`, `playing_style`, or `reliability_score` changes `match_score` and its corresponding `breakdown` field.
  - **Completion criteria:** Zero hardcoded `+ 0.45` remains in `main.py`, and all 5 factors actively determine ranking and breakdown output.

- [ ] **TASK-M4-02: Fix Local Python `.venv` Dependencies & Add 5-Factor `pytest` Suite** (Priority: **P0**)
  - **What to implement/fix:**
    1. Install missing `numpy` and test dependencies into `matchmaking/.venv` (`./.venv/bin/pip install -r requirements.txt`).
    2. Add comprehensive unit and endpoint tests in `matchmaking/tests/test_matcher.py` and `matchmaking/tests/test_api.py` covering:
       - Exact weight sum ($0.35 + 0.25 + 0.20 + 0.10 + 0.10 = 1.00$),
       - 6-axis cosine skill similarity (`smash`, `defense`, `netPlay`, `stamina`, `footwork`, `serve`),
       - Time slot overlap ratio,
       - Haversine distance decay and `max_distance_km` filtering,
       - Playing style compatibility matrix (`attacking`, `defensive`, `all-round`),
       - Reliability normalization (`1..5` stars / `0..100` score).
  - **Specific files/modules:** `matchmaking/requirements.txt`, `matchmaking/tests/test_matcher.py`, `matchmaking/tests/test_api.py`.
  - **Dependencies:** `TASK-M4-01`.
  - **How to test:** Run `./.venv/bin/pytest` in `matchmaking/`.
  - **Completion criteria:** `pytest` executes with 100% passing tests and zero `ModuleNotFoundError`.

- [ ] **TASK-M4-03: Verify End-to-End Ranking Quality with Seeded Da Nang Players & Smash Scot AI** (Priority: **P1**)
  - **What to implement/fix:** Validate `POST /matchmaking/recommend` against the 12 seeded Da Nang players (`TASK-M2-02`) to confirm candidates outside `max_distance_km` are filtered out, candidates with overlapping availability and higher reliability rank higher, and the recommendation helper can be invoked cleanly by Member 3's Smash Scot AI service (`TASK-M3-06`).
  - **Specific files/modules:** `matchmaking/app/services/matcher.py`, `backend/src/matchmaking.service.ts`.
  - **Dependencies:** `TASK-M2-02`, `TASK-M3-07`, `TASK-M4-01`.
  - **How to test:** Execute `POST /matchmaking/recommend` for `player1@smatch.vn` and verify deterministic descending `matchScore` order with all 5 breakdown fields populated.
  - **Completion criteria:** Live NestJS -> FastAPI recommendation call returns ranked Da Nang players with complete 5-factor explanations.

---

## 8. Critical Cross-Member Dependencies

| Upstream Blocker | Owner | Downstream Dependent Tasks | Why It Blocks |
|---|---|---|---|
| **1. `TASK-M2-01` (Apply 4 Pending Migrations)** | **Member 2 (DB)** | `TASK-M2-02`, `TASK-M2-03`, `TASK-M3-01`, Feedback/Rating E2E | `MatchFeedback`, `PlayerRating`, and analytics indexes do not exist in local PostgreSQL until `npx prisma migrate deploy` is run. |
| **2. `TASK-M2-02` (Seed 10 Da Nang Facilities & 12 Players)** | **Member 2 (DB)** | `TASK-M1-01`, `TASK-M4-03`, MapLibre & Booking E2E | Mobile Home/Explore/Map and Matchmaking need the 10 Da Nang facilities (20–40 courts) and 12 players with 6-axis skills in DB. |
| **3. `TASK-M3-01` (`GET /matches/my-invitations` & `/matches/my`)** | **Member 3 (Backend)** | `TASK-M1-03` (Mobile Match API wiring) | Mobile `MatchInvitationsScreen` and `MatchListScreen` need these 2 read endpoints to replace `MatchUiStore`. |
| **4. `TASK-M4-01` (FastAPI 5-Factor `POST /api/v1/match`)** | **Member 4 (Matchmaking)** | `TASK-M3-07` (`FastApiClient` 5-key contract) -> `TASK-M1-08` (Mobile UI) | NestJS `FastApiClient` currently strips breakdown keys other than `distance_score` and `skill_score`; FastAPI and NestJS must update their 5-key contract together. |
| **5. `TASK-M2-03` (`Booking.paymentStatus` Migration)** | **Member 2 (DB)** | `TASK-M3-03` (`PATCH /bookings/:id/payment-status`) -> `TASK-M1-04` (Owner Paid Button) | Backend cannot compile `Booking.paymentStatus` queries until Prisma schema is migrated and `@prisma/client` is regenerated. |
| **6. `TASK-M3-02` (`GET /candidates/nearby` Privacy + `availableNow`)** | **Member 3 (Backend)** | `TASK-M1-05` (`FindPlayersMapScreen` Available Now filter) | Mobile disables the `"Available Now"` chip until Backend includes `availableNow: boolean` in candidate responses. |
| **7. `TASK-M3-04` (`PUT /players/profile/me/skill`)** | **Member 3 (Backend)** | `TASK-M1-06A` (Dynamic Skill Radar & Assessment Screen) | Mobile `SkillAssessmentScreen` needs `PUT /players/profile/me/skill` and `include: { skill: true }` on profile fetch. |
| **8. `TASK-M3-06` (`POST /ai/chat`)** | **Member 3 (Backend)** | `TASK-M1-07` (`SmashScotChat` live integration) | Mobile `SmashScotChat` needs the `/ai/chat` endpoint to replace local `DemoCatalog` keyword matching. |

---

## 9. Top 10 Tasks to Execute First (Ordered by Unblocking Impact)

1. **`[Member 2] TASK-M2-01` — Run `npx prisma migrate deploy` & `npx prisma generate`:** Immediately unblocks `MatchFeedback`, `PlayerRating`, and analytics indexes in PostgreSQL in under 2 minutes.
2. **`[Member 2] TASK-M2-03` — Add `Booking.paymentStatus` (`PaymentStatus` enum) & Run Migration:** Unblocks Member 3's Finance endpoint (`TASK-M3-03`) and ensures all schema migrations are finished before seeding.
3. **`[Member 2] TASK-M2-02` — Expand `backend/prisma/seed.ts` to 10 Da Nang Facilities (20–40 Courts) & 12 Players:** Populates realistic Da Nang data for MapLibre, Player Home/Explore, Booking, Matchmaking, and Owner Dashboard.
4. **`[Member 4] TASK-M4-01` — Wire `POST /api/v1/match` in `matchmaking/app/main.py` to 5-Factor `MatchmakingEngine`:** Eliminates the hardcoded `+ 0.45` formula and returns all 5 breakdown scores (`skill`, `time`, `distance`, `style`, `reliability`).
5. **`[Member 3] TASK-M3-07` — Update `FastApiClient` & `MatchmakingService` for 5 Breakdown Keys + Fix `facilities.service.spec.ts`:** Connects Member 4's 5-factor output to NestJS `POST /matchmaking/recommend` and makes `npm test` pass in `backend/`.
6. **`[Member 3] TASK-M3-01` — Add `GET /matches/my-invitations` and `GET /matches/my` in `MatchesController`:** Completes the Backend Match API so Member 1 can wire all 6 Mobile match screens.
7. **`[Member 1] TASK-M1-01` & `TASK-M1-02` — Connect `PlayerHomeScreen`/`ExploreCourtsScreen`/`ExperienceSearchScreen` to `GET /facilities` & Wire Live Booking Cancel:** Removes the negative demo court IDs from Player Home/Explore and completes the end-to-end Booking + Cancellation loop.
8. **`[Member 1] TASK-M1-03` — Replace `MatchUiStore` with Live `/matches` APIs across All 6 Match Screens:** Turns Open/Private Match creation, invitations, join requests, approvals, and completion into a real multi-user PostgreSQL workflow.
9. **`[Member 3] TASK-M3-02` & `TASK-M3-03` — Fix `GET /candidates/nearby` Privacy/`availableNow` & Implement `PATCH /bookings/:id/payment-status`:** Fixes the player coordinate privacy leak and unlocks live collected revenue tracking for Court Owners.
10. **`[Member 1] TASK-M1-04` — Render Live 2D `DashboardScheduleGrid` (`Court x TimeSlot`) & Owner Payment Confirmation Button:** Completes the Court Owner Dashboard & Finance workflow on Simulator.

---

## 10. Definition of Done (Final Capstone Demonstration Gates)

The S-Match project is ready for the final Capstone demonstration when all of the following technical gates are verified:

- [ ] **Gate 1 — Database & Seed Readiness:**
  - `npx prisma migrate status` reports all migrations applied (`0` pending).
  - `npx prisma db seed` runs idempotently and populates **2 Court Owners (6–4 facility split)**, **10 Da Nang Facilities**, **20–40 Courts**, **16 hourly `TimeSlot`s per court**, and **12 Players** with 6-axis `Skill` and `Availability` records.
- [ ] **Gate 2 — Automated Test Suites Green:**
  - **Backend (`backend/`):** `npm test` passes all unit test suites (including `facilities.service.spec.ts`), and `npm run test:e2e` passes against the isolated `test_integration` schema without mutating `public` demo data.
  - **Matchmaking (`matchmaking/`):** `./.venv/bin/pytest` passes all 5-factor scoring and API contract tests with zero `ModuleNotFoundError`.
  - **Mobile (`mobile/`):** `flutter analyze` reports no errors and `flutter test` passes.
- [ ] **Gate 3 — Zero Unintended Demo Fallbacks in Core Flows:**
  - `PlayerHomeScreen`, `ExploreCourtsScreen`, `ExperienceSearchScreen`, and `FindCourtsMapScreen` load the 10 real Da Nang facilities from `GET /facilities` and navigate to live `BookingFacilityScheduleScreen`.
  - Creating, viewing, and cancelling a booking from `BookingDetailScreen` persists to PostgreSQL and prevents concurrent double-bookings (`409 Conflict` via `SELECT ... FOR UPDATE`).
  - Creating Open/Private matches, sending invitations, requesting to join, approving requests, and completing matches persist to PostgreSQL via `/matches/*` (not `MatchUiStore`).
- [ ] **Gate 4 — 5-Factor Matchmaking, 6-Axis Skill Radar & Post-Match Rating Separation:**
  - `POST /matchmaking/recommend` executes `MatchmakingEngine` across all 5 weighted factors (`skill` 0.35, `time` 0.25, `distance` 0.20, `style` 0.10, `reliability` 0.10) and displays all 5 breakdown scores in Flutter.
  - `GET /candidates/nearby` returns `distanceKm` and `availableNow` without leaking raw `latitude`/`longitude`.
  - `SkillAssessmentScreen` saves 6-axis skills via `PUT /players/profile/me/skill` and `ProfileSkillRadar` dynamically draws the polygon via `CustomPainter`; post-match feedback (`POST /ratings`) updates `reliabilityScore` without mutating technical `Skill` axes.
- [ ] **Gate 5 — Owner Dashboard, 2D Schedule, Finance & Smash Scot AI:**
  - `DashboardScreen` in live mode renders the 2D `Court x TimeSlot` matrix (`DashboardScheduleGrid`), allows the Court Owner to mark a booking `PAID` via `PATCH /bookings/:id/payment-status`, and updates `collectedRevenue` in `GET /analytics/revenue`.
  - `SmashScotChat` calls `POST /ai/chat` and returns role-appropriate live PostgreSQL data for both Players and Court Owners.

