# S-MATCH — POST-TEAM-INTEGRATION STATUS REPORT

**Document ID:** `SMM-REPORT-TEAM-STATUS-01`  
**Author:** Technical Lead & Member 1 (Mobile Lead & Smash Scot AI Owner)  
**Target Audience:** Project Technical Lead, Academic Supervisors, Team Members (M2, M3, M4)  
**Audit Date:** November 13, 2026  
**Repository Branch Inspected:** `feature/SMM-41-FinalIntegrationTestingRelease` (HEAD commit `7fa3654`) compared against `origin/develop` (commit `38a978f`)  
**Operating Mode:** Strict Read-Only Audit & Non-Destructive Verification  

---

## EXECUTIVE SUMMARY & CRITICAL BRANCH FINDINGS

1. **Branch Divergence Alert:**  
   The current local checkout is on branch `feature/SMM-41-FinalIntegrationTestingRelease` at commit `7fa3654`.  
   On the remote repository, four Pull Requests were merged into `origin/develop` on November 12, 2026:
   - PR #42: `feature/SMM-41-FinalIntegrationTestingRelease` (Merge commit `0566c30`)
   - PR #43: `feature/SMM-42-BackendIntegrationTesting` (Member 3, commit `a01dbff`)
   - PR #44: `feature/SMM-43-MatchmakingFinalTesting` (Member 4, commit `a9e7a46`)
   - PR #45: `feature/SMM-44-Database_And_Backend_Feature_Testing` (Member 2, commit `38a978f`)  
   **Result:** The local working tree has **not** merged `origin/develop`. Several completed assets from Members 2, 3, and 4 are already present in `origin/develop` but missing from the local working tree.

2. **Cross-Module Breaking Incompatibility (Fatal 502 Bad Gateway):**  
   Member 4 updated FastAPI in PR #44 to return 5 breakdown factors (`skill_score`, `distance_score`, `time_score`, `reliability_score`, `style_score`).  
   However, Member 3's NestJS adapter in `backend/src/matchmaking/fastapi.client.ts` (lines 10 & 87–99) strictly validates:
   ```typescript
   export const FASTAPI_BREAKDOWN_KEYS = ['distance_score', 'skill_score'] as const;
   ```
   If `keys.length !== FASTAPI_BREAKDOWN_KEYS.length`, NestJS throws `BadGatewayException('Phản hồi dịch vụ matchmaking không hợp lệ')`.  
   **Impact:** When NestJS connects to FastAPI with 5-factor scoring, all matchmaking requests with breakdowns will immediately fail with HTTP 502.

3. **Backend Breakdown & Skill DTO Drop:**  
   Even if the FastAPI client validation is fixed, NestJS `matchmaking.service.ts` (lines 55–67) and `MatchmakingResponseDto` do **not** map or return `breakdown` to Flutter. All breakdown scores are dropped before reaching mobile.

---

## PART 1 — VERIFICATION OF MEMBER DELIVERABLES

### 1. Member 2: Database, Migrations, Seed & Data Integrity

| Deliverable Item | Status | Source Evidence (File & Lines) | Verdict & Integration Readiness |
| :--- | :--- | :--- | :--- |
| **Prisma Migrations** | **IMPLEMENTED ON DEVELOP, MISSING LOCALLY** | `backend/prisma/migrations/20261112090000_smm_44_integrity_constraints/migration.sql` (commit `682a127f`) | 14 migrations exist locally up to `20261101120000_smm_40_analytics_indexes`. SMM-44 migration adds PostgreSQL `btree_gist` extension, `Booking` exclusion constraint for non-overlapping active bookings, and `CHECK (startTime < endTime)`. Present on `origin/develop`, missing in local branch. |
| **10 Da Nang Facilities & 2 Owners** | **IMPLEMENTED ON DEVELOP, MISSING LOCALLY** | Local: `backend/prisma/seed.ts` (lines 109–123).<br>Develop: `backend/prisma/seed-smm44.ts` (lines 28–46). | Local seed has only 1 facility (`id: 1`, S-Match Demo Badminton Center) and 1 Owner (`owner@smatch.dev`). SMM-44 seed on develop seeds 10 facilities across Hai Chau, Thanh Khe, Son Tra, Ngu Hanh Son, Cam Le, and Lien Chieu under 2 owners (`owner@smatch.dev` and `owner2@smatch.dev`). |
| **20+ Players with Profiles & Skills** | **IMPLEMENTED ON DEVELOP, MISSING LOCALLY** | Local: `backend/prisma/seed.ts` (lines 222–284).<br>Develop: `backend/prisma/seed-smm44.ts` (lines 48–50, 160–210). | Local seed has 4 players (`player@smatch.dev`, `player2..4@smatch.dev`). SMM-44 seed creates `player5@smatch.dev` through `player20@smatch.dev` (16 additional players, total 20 players), each with profile coordinates, skill records, playing preferences, and availability slots. |
| **Courts, TimeSlots, Availability & Matches** | **IMPLEMENTED ON DEVELOP, MISSING LOCALLY** | Local: `backend/prisma/seed.ts` (lines 132–214).<br>Develop: `backend/prisma/seed-smm44.ts` (lines 80–150, 220–310). | Local seed has 4 courts and 0 matches. SMM-44 seed generates 29 courts, 4 slot windows/day/court, 30 sample bookings (10 COMPLETED, 15 CONFIRMED, 5 CANCELLED), and 8 sample matches linked to bookings. |
| **PaymentStatus & paidAt Fields** | **MISSING** | `backend/prisma/schema.prisma` (lines 226–254) | `BookingStatus` enum contains only `PENDING`, `CONFIRMED`, `CANCELLED`, `COMPLETED`. No `PaymentStatus` enum exists. No `paidAt` or `paymentStatus` column exists on `model Booking`. Both local branch and develop lack payment schema. |
| **locationSharingConsent Field** | **MISSING** | `backend/prisma/schema.prisma` (lines 83–105) | `PlayerProfile` contains `latitude`, `longitude`, `locationUpdatedAt`. No `locationSharingConsent` or privacy flag exists in `schema.prisma`. |
| **Idempotent Seed & Database Invariants** | **IMPLEMENTED ON DEVELOP, MISSING LOCALLY** | `backend/prisma/seed-smm44.ts` (lines 1–25, 310–330), `backend/scripts/smm44-rebuild-clean-db.ts` | Uses natural keys (`email`, `(ownerId, name)`, `(courtId, dayOfWeek, startTime)`, booking notes, match titles) to ensure re-run idempotency without duplicate key violations. |
| **Data Integrity Live Test Evidence** | **IMPLEMENTED, NOT INTEGRATION-TESTED LOCALLY** | `backend/src/database/smm44-db-integrity.live.spec.ts` (539 lines, 10 scenarios) | Comprehensive test suite for double-booking exclusion, check constraints, cascade deletes. Requires running PostgreSQL container with `btree_gist` extension; not runnable without local database setup. |

---

### 2. Member 3: NestJS Business APIs, Auth, Match, Booking & Security

| Deliverable Item | Status | Source Evidence (File & Lines) | Verdict & Integration Readiness |
| :--- | :--- | :--- | :--- |
| **GET /matches/my** | **MISSING** | `backend/src/matches/matches.controller.ts`, `matches.service.ts` | Route does not exist. Flutter has no endpoint to fetch matches created by or joined by the logged-in player. |
| **GET /matches/my-invitations** | **MISSING** | `backend/src/matches/matches.controller.ts`, `matches.service.ts` | Route does not exist. Flutter cannot fetch match invitations targeted to the authenticated player. |
| **Match Lifecycle & Invitation Endpoints** | **IMPLEMENTED & TESTED** | `backend/src/matches/matches.controller.ts` (lines 39–285), `matches.service.ts` (lines 1–400) | `POST /matches`, `GET /matches/:id`, `PATCH /matches/:id`, `PATCH /matches/:id/cancel`, `PATCH /matches/:id/complete`, `POST /matches/:id/feedback`, `POST /matches/:id/invite`, `POST /matches/:id/join-request`, `PATCH /matches/:id/invitations/accept`, `PATCH /matches/:id/invitations/reject`, `PATCH /matches/:id/requests/:userId/approve`, `PATCH /matches/:id/requests/:userId/reject`, `POST /matches/bookings/:bookingId/open-match`, `GET /matches/open-matches`, `GET /matches/open-matches/:id`, `POST /matches/open-matches/:id/join`, `PATCH /matches/open-matches/:id/participants/:id/accept`, `PATCH /matches/open-matches/:id/participants/:id/reject`, `PATCH /matches/open-matches/:id/leave`. Unit tests pass (`matches.service.spec.ts`, `matches.lifecycle.spec.ts`, `matches.security.spec.ts`). |
| **GET / PUT Six-Axis Player Skill** | **MISSING** | `backend/src/players/players.controller.ts`, `players.service.ts` (lines 9–60) | Model `Skill` exists in Prisma, but `players.controller.ts` has only `GET /players/profile/me` and `PATCH /players/profile/me`. `getMyProfile` does not include the `skill` relation. No skill GET/PUT endpoints exist. |
| **Nearby Player Privacy & availableNow** | **MISSING** | `backend/src/candidates/candidates.controller.ts` (lines 29–35), `candidates.service.ts` (lines 109–117) | `GET /candidates/nearby` exposes raw `latitude` and `longitude` of candidates without obfuscation. No `locationSharingConsent` check exists. `availableNow` field is completely missing from backend. |
| **Booking Cancellation API** | **IMPLEMENTED & TESTED** | `backend/src/bookings/bookings.controller.ts` (lines 75–84), `bookings.service.ts` (lines 221–260) | `PATCH /bookings/:id/cancel` checks booking ownership/role, validates transition from PENDING/CONFIRMED, and updates status to `CANCELLED`. Unit tested in `bookings.service.spec.ts`. Ready for mobile integration. |
| **Owner Finance & Analytics APIs** | **IMPLEMENTED & TESTED** | `backend/src/analytics/revenue-analytics.controller.ts` (lines 13–47), `backend/src/bookings/bookings.controller.ts` (lines 57–62) | `GET /bookings/owner`, `GET /analytics/revenue/overview`, `GET /analytics/revenue/trend`, `GET /analytics/revenue/court-utilization`. Unit tested in `revenue-analytics.service.spec.ts` (14 test cases pass). |
| **POST /auth/google** | **MISSING** | `backend/src/auth/auth.controller.ts` (lines 1–52) | Only `register`, `login`, `refresh`, `logout` exist. Google OAuth endpoint is not implemented on backend. |
| **FacilitiesService Unit Tests** | **PARTIAL / PLACEHOLDER ONLY** | Local: `backend/src/facilities/facilities.service.spec.ts` (0 bytes).<br>Develop: PR #43 (lines 1–34). | In local branch, the file is 0 bytes, causing `npm test` to fail. In `origin/develop`, Member 3 committed a single placeholder test (`expect(service).toBeDefined()`). No functional tests exist for CRUD, ownership, or time-slot cascading. |
| **Auth/RBAC & API Integration Tests** | **IMPLEMENTED, NOT INTEGRATION-TESTED** | `backend/src/auth/auth.register.spec.ts`, `backend/src/auth/auth.sessions.spec.ts`, `backend/test/integration-e2e.spec.ts` | Unit tests for auth pass (7.1s). However, `backend/test/integration-e2e.spec.ts` added in PR #43 contains 5 test cases with dummy assertions (`expect(true).toBe(true)`). |

---

### 3. Member 4: FastAPI Matchmaking & Five-Factor Scoring

| Deliverable Item | Status | Source Evidence (File & Lines) | Verdict & Integration Readiness |
| :--- | :--- | :--- | :--- |
| **FastAPI /api/v1/match Implementation** | **PARTIAL** | Local: `matchmaking/app/main.py` (lines 100–180).<br>Develop: PR #44 (commit `ac477bf`). | Endpoint exists in both branches. In local branch, it uses a 2-factor formula. In `origin/develop`, it implements 5-factor scoring. |
| **Five-Factor MatchmakingEngine Integration** | **PARTIAL** | `matchmaking/app/main.py` (lines 150–170) vs `matchmaking/app/services/matcher.py` | The external service `matcher.py` is not invoked. Instead, scoring logic is directly inlined in `main.py`. |
| **Elimination of Hardcoded +0.45 Constant** | **LOCAL: NOT ELIMINATED / DEVELOP: ELIMINATED** | Local: `matchmaking/app/main.py` (line 157).<br>Develop: PR #44 (diff on lines 157–185). | Local code still contains: `total_score = float((skill_similarity * 0.3 + (distance_score / 100.0) * 0.25 + 0.45) * 100)`. In PR #44 on develop, this was replaced with: `(skill*0.30) + (distance*0.25) + (time*0.20) + (rel*0.15) + (style*0.10)`. |
| **Five-Factor Breakdown in Response** | **IMPLEMENTED IN FASTAPI, BLOCKED IN NESTJS** | FastAPI: `matchmaking/app/main.py` (lines 173–182).<br>NestJS: `backend/src/matchmaking/fastapi.client.ts` (lines 10, 87–99). | FastAPI returns `skill_score`, `distance_score`, `time_score`, `reliability_score`, `style_score`. NestJS client throws 502 error because it expects exactly 2 keys (`distance_score`, `skill_score`). |
| **Ranking Tests & Deterministic Ordering** | **IMPLEMENTED & TESTED** | `matchmaking/test/test_api.py`, `test_matchmaking.py`, `test_sprint7_scoring_topk.py` | 19 pytest test cases pass cleanly in 0.60s. Sorting is deterministic by `(-match_score, distance_km)`. |
| **NestJS ↔ FastAPI Response Compatibility** | **BLOCKED** | `backend/src/matchmaking/fastapi.client.ts` (lines 10, 87–99), `backend/src/matchmaking.service.ts` (lines 55–68) | Incompatible breakdown key validation causes immediate HTTP 502. Furthermore, NestJS drops `breakdown` from the final response DTO. |

---

## CROSS-MODULE COMPATIBILITY MATRIX

```mermaid
flowchart TD
    Flutter["Flutter Mobile (M1)"]
    NestJS["NestJS Gateway (M3)"]
    FastAPI["FastAPI Engine (M4)"]
    Postgres["PostgreSQL / Prisma (M2)"]

    Flutter -- "POST /matchmaking/recommend" --> NestJS
    NestJS -- "POST /api/v1/match" --> FastAPI
    FastAPI -- "Returns 5 breakdown factors" --> NestJS
    NestJS -. "THROWS 502 BAD GATEWAY\n(fastapi.client.ts expects 2 keys)" .-> Flutter
    NestJS -. "DROPS breakdown from DTO" .-> Flutter

    Flutter -- "PATCH /bookings/:id/cancel" --> NestJS
    NestJS -- "Updates status=CANCELLED" --> Postgres
    note1["Booking Cancel: FULLY COMPATIBLE"]

    Flutter -- "GET /matches/my & /my-invitations" -. "404 NOT FOUND\n(Routes Missing)" .-> NestJS
    Flutter -- "GET/PUT /players/skills" -. "404 NOT FOUND\n(Routes Missing)" .-> NestJS
    Flutter -- "POST /auth/google" -. "404 NOT FOUND\n(Route Missing)" .-> NestJS
```

---

## OUTSTANDING BLOCKERS & CRITICAL RISKS

1. **Local Branch Stale Baseline (CRITICAL):**  
   Local branch `feature/SMM-41-FinalIntegrationTestingRelease` does not contain PR #43, #44, #45. To work on live code, Member 1 must merge or rebase `origin/develop` into their working branch once permitted by team protocol.
2. **FastAPI Client Breakdown Key Crash (CRITICAL):**  
   Until line 10 of `backend/src/matchmaking/fastapi.client.ts` is updated to include all 5 factors or allow flexible breakdown keys, calling matchmaking through NestJS will crash with HTTP 502.
3. **Missing DTO Fields for Mobile Recommendations (HIGH):**  
   `MatchmakingResponseDto` must be updated to include `breakdown` and `distanceKm` so Flutter can render the five-factor compatibility card.
4. **Missing Match Management Endpoints (HIGH):**  
   Without `GET /matches/my` and `GET /matches/my-invitations`, mobile match lists cannot display user-specific data from the database.
5. **Missing Skill & Google Auth Endpoints (MEDIUM):**  
   Six-axis skill radar and Google sign-in cannot be backed by real APIs without backend controller endpoints.
