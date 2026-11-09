# S-Match — Shared Final Sprint baseline: setup, handoff and review

Prepared: **09/11/2026**. Scope: preserve existing work, verify readiness and fix common setup/build configuration only. **No approved Final Sprint task was implemented.**

## 1. Commit identity and Git safety

| Item | Verified value |
| --- | --- |
| Current branch | `feature/SMM-41-FinalIntegrationTestingRelease` |
| Exact HEAD | `4090d678b7a9ef2d59521d811e8e44fbbcd872eb` |
| Local `develop` | `4090d678b7a9ef2d59521d811e8e44fbbcd872eb` |
| Remote `develop`, checked with read-only `git ls-remote` | `4090d678b7a9ef2d59521d811e8e44fbbcd872eb` |
| Divergence from `develop` | 0 commits ahead / 0 behind |
| Proposed shared baseline SHA | **Not assigned: the reviewed working tree has not been committed.** |

The HEAD above does **not** contain the existing uncommitted changes or these setup fixes. Do not give that SHA to teammates as if it included them. An exact new commit SHA cannot truthfully be provided without creating a commit, which is explicitly prohibited during preparation.

At the start there were **69 modified tracked files and 54 untracked files**. Preserve all of them for review, including binary assets. See [WORKTREE-PRESERVATION.md](WORKTREE-PRESERVATION.md). No branch switch, staging, commit, fetch/ref update, stash, reset, clean, rebase, merge or push was performed. The remote SHA was read without fetching.

## 2. Changes made by preparation only

| File | Verified setup problem / reason |
| --- | --- |
| `backend/.gitignore` | Contained committed merge-conflict markers. Removed only marker lines and retained the rules from both sides. |
| `backend/package.json` | `start:prod` pointed at `dist/main`; a fresh TypeScript build produces `dist/src/main.js`. Corrected the script path. |
| `backend/Dockerfile` | Corrected the same production entrypoint. Aligned both stages to Node 24: installed Vitest requires Node 22.12+, 24, or 26+, while the previous image used Node 20. |
| `backend/.nvmrc` (new) | Makes the supported Node 24 major discoverable for all developers. No dependency or lockfile upgrade. |
| `backend/test/jest-e2e.json` | Added the relative `.js` → TypeScript module mapping already used by the main Jest config. The existing app E2E imports `app.module.js` from TypeScript source. Discovery was checked; DB-dependent execution was not run. |
| `backend/.dockerignore`, `matchmaking/.dockerignore` | Exclude local `.env.*` and credential file patterns from image contexts. The backend previously excluded only exact `.env`; FastAPI did not exclude env files. Templates remain allowed. |
| `mobile/ios/Runner.xcodeproj/project.pbxproj` | Align Runner and test deployment targets to the project's existing iOS 15.5 minimum. MapLibre requires 15.5, but target-level “recommended” overrides resolved to 15.0 and broke SwiftPM native build. |
| `README.md` | Links this handoff and corrects the claim that root Compose provisions PostGIS; it currently provisions plain PostgreSQL. |
| `docs/baseline/*` (new) | Setup, verification, preservation inventory, contracts, ownership and review/commit plan. |

No changes to application business logic, Prisma schema, migrations, seed, Flutter Demo/Live selection or FastAPI algorithm. None of the previously modified application files was overwritten. Final verification compares original source files with their initial content digests.

## 3. Team toolchain and addresses

| Component | Setup baseline |
| --- | --- |
| NestJS | Node 24, npm, lockfile in `backend/`; Docker runtime verified with Node 24.22.2 |
| Flutter | Verified Flutter 3.47.2 / Dart 3.13.2; pubspec requires Dart `^3.13.2` |
| FastAPI | Python 3.11 in Docker; existing Python 3.9 virtualenv also passes tests; use declared requirements |
| Database | PostgreSQL 16; root Compose publishes port 5432 and retains a named volume |
| iOS | Xcode with Swift Package Manager, iOS deployment target 15.5+ for MapLibre |
| Android | Android SDK and compatible JDK; this machine's Flutter uses Android Studio JDK 21. Android licenses still need the developer's own review/acceptance. |

Addresses with the current configuration:

- Backend on the development host: `http://localhost:3000`.
- Swagger: `http://localhost:3000/api/docs`.
- FastAPI: `http://localhost:8000`; docs: `http://localhost:8000/docs`; matching endpoint: `http://localhost:8000/api/v1/match`.
- Flutter Android emulator reaches NestJS at `http://10.0.2.2:3000`; iOS Simulator/macOS uses `http://localhost:3000`.
- `ApiClient` currently chooses these addresses in code. There is no supported generic `API_BASE_URL` dart-define. Physical-device/LAN setup is not certified by this preparation.
- Root Compose starts **only PostgreSQL**. `matchmaking/docker-compose.yml` independently builds/publishes FastAPI. There is no combined backend+FastAPI+DB Compose stack.
- If backend itself is containerized, `localhost` points inside that container. The lead must provide the appropriate service/host network addresses; do not reuse host-only URLs blindly.

## 4. Environment variables — names only

Use `backend/.env.example` as the backend template, not the root template. Copy only when the target `.env` does not already exist; never replace a teammate's working `.env`.

| Category | Names |
| --- | --- |
| Backend required at startup | `DATABASE_URL`, `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET` |
| Required for live recommendation calls | `MATCHMAKING_API_URL` |
| Backend optional | `PORT`, `NODE_ENV`, `JWT_ISSUER`, `MATCHMAKING_TIMEOUT_MS` |
| Existing test opt-ins; leave disabled for baseline checks | `RUN_BOOKING_LIVE`, `RUN_RECOMMENDATION_LIVE` |
| Existing Flutter build flags | `SPRINT7_LIVE_API`, `SPRINT7_USE_MOCKS` |
| Legacy scoring settings, not wired into the active FastAPI handler | `WEIGHT_SKILL`, `WEIGHT_DISTANCE`, `WEIGHT_TIME`, `WEIGHT_STYLE`, `WEIGHT_RELIABILITY`, `MAX_DISTANCE_KM` |

JWT signing secrets must be private, distinct and at least 32 characters. Do not use the template markers as real shared secrets. Obtain sandbox DB access and existing account credentials from the Database Lead privately. No secret values are included in this handoff.

The active FastAPI app has no mandatory environment variable for basic startup. No Google OAuth or LLM secret configuration is required by the current implementation; those contracts are future backlog work and are not invented here.

## 5. Running each member's component

### Common checkout rule

First wait for the team lead's reviewed merge and published exact shared SHA. All four members must start from that same SHA, not from a moving `develop` or a copy of an uncommitted working directory.

### Member 1 — Flutter / Mobile Lead

From `mobile/`:

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter test
flutter run -t lib/main_dev.dart
```

The normal app entrypoint is `lib/main.dart`:

```sh
flutter run -t lib/main.dart
```

To enable the existing live recommendation repository in Dev Hub:

```sh
flutter run -t lib/main_dev.dart --dart-define=SPRINT7_LIVE_API=true
```

Do not combine that with `SPRINT7_USE_MOCKS` when checking live recommendations. The live flag is **not** a global switch making every screen live. Home/Catalog demo content, Dashboard previews, screen-explorer examples and demo bookings remain separately explicit.

Dev Hub's “Add account” saves test-account metadata; it does not register a user or grant a backend role. Quick Login requires an account already present in the approved sandbox database.

For iOS, use Flutter's build/run command so it regenerates ignored SwiftPM files with the correct target. Do not hand-edit or commit `ios/Flutter/ephemeral` to fix cached platform metadata. Android license acceptance is an action for each developer, not performed automatically here.

### Member 2 — Database & Data Integrity Lead

From the repo root, validate the Compose definition and inspect the existing service:

```sh
docker compose config --quiet
docker compose ps
```

On an approved developer machine, the existing database service can be started with:

```sh
docker compose up -d postgres
```

Starting an empty database does not provision Prisma tables or application records. The approved `TASK-M2-01` / `TASK-M2-02` own migration safety and data preparation. They are **not executed by this handoff**. Do not run `db:migrate`, `db:deploy`, `db:seed`, reset, or volume deletion as a generic onboarding shortcut.

From `backend/`, read-only validation is:

```sh
npx prisma validate
npx prisma migrate status
```

The current database has four pending migrations (listed in section 10). Provide the team with the chosen sandbox address, supported schema state and credentials privately after the separately approved DB work. Root Compose is plain PostgreSQL; `database/init/001_init_extensions.sql` is not mounted by that Compose file. Do not assume PostGIS is available.

### Member 3 — NestJS / Backend Lead

From `backend/`, with Node 24 selected and a privately configured `.env`:

```sh
nvm install
nvm use
npm ci
npm run db:generate
npm run build
npm run start:dev
```

`db:generate` generates Prisma client code; it does not apply schema changes or seed the database. The backend still needs an already provisioned database to start normally. `npm run start:prod` uses the corrected compiled entrypoint after a build.

Safe baseline tests, with the two live-test opt-ins disabled in the shell:

```sh
npm test -- --runInBand
npm run lint
```

The full Jest command currently fails for the known empty FacilitiesService suite; do not suppress that file or add a meaningless test to claim green. The approved `TASK-M3-03` owns real FacilitiesService coverage. `npm run test:e2e` boots the real app and needs a prepared database and environment; only config/discovery were checked here.

### Member 4 — FastAPI / Matchmaking Lead

From `matchmaking/`, on a fresh checkout without an existing `.venv`:

```sh
python3.11 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m pip check
.venv/bin/python -m pytest -q
.venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Keep an existing working virtualenv; do not replace it blindly. Use `python -m pytest` from this directory so `app` resolves correctly. NumPy is already declared in requirements. The Docker alternative is:

```sh
docker compose -f docker-compose.yml up --build
```

That command belongs in `matchmaking/`; it is not the root PostgreSQL Compose file. The active app is `app.main:app`. Passing tests for `app.services.matcher.MatchmakingEngine` does not prove that this five-factor engine is used by the active HTTP handler; that is explicitly `TASK-M4-01`, not part of this baseline preparation.

## 6. Demo and Live boundaries to preserve

| Area | Current boundary |
| --- | --- |
| Dev Hub recommendations | Fixtures by default; explicit existing flag opts into API |
| Map facilities | Existing live facility endpoint; real facility IDs must be preserved |
| Home / Explore / Catalog / Scot | Explicit local demo catalog, negative IDs and demo responses where present |
| Demo booking | Session-only service; not written to PostgreSQL or real Player history |
| Live booking | Positive facility/court IDs, server availability/pricing, authenticated confirmation and API-backed history |
| Dashboard | Explicit preview flag vs authenticated real Owner/Admin repositories |
| Screen Explorer | Some pages are UI examples even while other pages use real APIs |

Do not remove demo data or make demo success appear as a real reservation. Do not replace real API failures with fixtures. Ten demo facilities are not evidence that ten real facilities have been seeded.

## 7. Existing API contracts in the candidate working tree

These describe the preserved candidate work, including uncommitted P0.1. They are not a claim that the unchanged HEAD already contains every endpoint below. Swagger remains the runtime reference after Member 2 provisions the schema.

| Area | Existing routes and contract |
| --- | --- |
| Auth | `POST /auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`; login returns `accessToken`, `refreshToken`, `user`. Bearer token identifies user/role; client must not supply trusted identity. |
| Facilities | Public `GET /facilities`, `GET /facilities/:id`; Owner `GET /facilities/my`; existing facility/court CRUD and operating-hours/time-slot management routes. |
| Availability | `GET /facilities/:id/courts/:courtId/time-slots/availability?date=YYYY-MM-DD`; returns slot IDs, local start/end time, configured price and `isBooked`. Booking occupancy is checked for that Vietnam date. |
| Booking | `POST /bookings` takes `courtId`, optional `facilityId`, timezone-qualified `startTime`/`endTime`, optional note. Price/user/status are server-owned. Booking must cover configured active slots; overlap returns 409. |
| Booking reads | `GET /bookings/my`, `GET /bookings/:id`; Owner-only `GET /bookings/owner` filters by `facilityId`, `startDate`, `endDate`. `PATCH /bookings/:id/cancel` already exists. |
| Player profile | `GET /players/profile/me`, `PATCH /players/profile/me`; six-axis skill contract is incomplete (see missing API list). |
| Discovery | `PUT /candidates/me/location`, `GET /candidates/nearby`, `GET /candidates/matchmaking-request`. Raw candidate coordinates/privacy and `availableNow` remain backlog work. |
| NestJS matching | `POST /matchmaking/recommend` takes availability timestamps, location, max distance and optional skill/style filters; returns `matchedUsers` in ranked order with `userId`, `matchScore`, public `profile`, plus processed count. |
| FastAPI matching | NestJS sends `current_user` + `candidates`, snake_case skills/time/location. `/api/v1/match` returns object `matched_users` + `total_candidates_processed` in this mode; legacy host payloads can return an array. Do not break that distinction unintentionally. |
| Recommendation history | `GET /recommendations/history`, `/stats`, `/:id`; outcome PATCH and session DELETE. Existing search history integration is preserved. |
| Matches / Open Match | Existing create/read/update/state and invitation/join mutations, plus `POST /bookings/:bookingId/open-match`, `/open-matches` read/join/participation routes. Global “my matches / my invitations” reads are missing. |
| Feedback / rating | `POST /matches/:id/feedback`, `/ratings` and pending/given/user summary/history/update reads/mutations exist; complete schema/environment and live UI flow are not certified. |
| Analytics | Owner/Admin overview, court performance, revenue overview/trend/utilization exist. Gross booked value is not the same as collected payment revenue. |

Known **missing** APIs, deliberately not implemented:

- `GET /matches/my`, `GET /matches/my-invitations` — Member 3, `TASK-M3-01`.
- `PUT /players/profile/me/skill` plus consistent six-axis profile response — Member 3, `TASK-M3-02`.
- `POST /auth/google` — Member 3, `TASK-M3-05`; mobile integration Member 1, `TASK-M1-07`.
- `PATCH /bookings/:id/payment-status`, collected/outstanding revenue contract — Members 2/3, `TASK-M2-04` / `TASK-M3-04`; mobile Member 1, `TASK-M1-04`.
- `POST /ai/chat` and role-aware tools — Member 3, `TASK-M3-06`; mobile feature owner Member 1, `TASK-M1-05`.
- Optional `GET /catalog/courses`, `/coaches`, `/shops` — Members 2/3/1 only if the lead approves Catalog Option A.

## 8. Approved task ownership — reference only

Source of truth: [approved execution backlog](../audits/FINAL-SPRINT-EXECUTION-BACKLOG.md), with the [requirement matrix](../audits/FINAL-SPRINT-REQUIREMENT-MATRIX.md). Existing audit counts/claims may predate this preparation; use the measurements below for current test status.

| Owner | Existing incomplete work to pick up after the common baseline |
| --- | --- |
| Member 1 — Mobile Lead | Live Open Match/invitations, Home/Explore/Map identity/data sync, cancellation/location wiring, real Owner 2D schedule, Skill Radar, Google UI, AI UI, Finance UI, optional catalog integration and real Simulator E2E coordination (`TASK-M1-01..09`) |
| Member 2 — DB Lead | Safe migration plan for four pending migrations; stable ten-facility/two-owner seed; DB isolation; payment/consent schema and optional catalogs (`TASK-M2-01..06`) |
| Member 3 — Backend Lead | Missing APIs above; profile skills; candidate privacy/availability; meaningful FacilitiesService tests; API/security E2E (`TASK-M3-01..08`) |
| Member 4 — Matchmaking Lead | Wire five-factor engine to real endpoint, maintain Python runtime, ranking E2E and breakdown propagation (`TASK-M4-01..04`) |

Security/dependency audit findings below also require lead/Backend Lead triage; this preparation neither upgrades dependencies nor silently adds scope to the approved backlog.

## 9. Verification performed in this preparation

| Check | Observed result |
| --- | --- |
| Remote/local develop comparison | Exact same HEAD; no divergence |
| `npm ci --dry-run --ignore-scripts --offline --no-audit --no-fund` | Pass; the invoking shell's Node 25 triggered a Vitest engine warning, addressed by explicit Node 24 setup/image choice |
| Fresh TypeScript build into a new temporary output directory | Pass; output is `src/main.js` under that output directory |
| Full backend Jest, live opt-ins explicitly disabled | **938 tests pass; 7 skipped; 36 suites pass, 2 skipped, 1 suite fails** because `facilities.service.spec.ts` is empty |
| Backend lint | Exit 0 with 7 existing warnings; no source edits to hide them |
| `prisma validate` | Pass; schema unchanged |
| Prisma migration status | Read-only: 4 pending; none executed |
| `npm run test:e2e` | Not executed against DB; config/test discovery only verified |
| Flutter complete widget/unit suite | **193/193 pass** |
| Flutter analyze | 22 info-level existing issues, no error/warning; command exits 1 under default strict settings |
| Flutter app and Dev Hub debug bundle builds | Both pass |
| Native iOS Simulator | **Pass after the setup fix**: Flutter built the Dev Hub iOS Simulator Runner.app (debug, unsigned); no installation or live device E2E |
| Python complete suite | **19/19 pass** locally; **19/19 pass in the clean Python 3.11 image**; existing deprecation warnings remain |
| Python dependency consistency | `pip check` pass |
| Docker Compose config | Both files validate; FastAPI Compose emits an obsolete `version` warning |
| Clean Docker builds | Backend Node 24 and FastAPI Python 3.11 images both pass |
| Image runtime imports, no server/DB | Backend bcrypt/Prisma and FastAPI imports pass; `.env` absent in both images |
| Production dependency audit (read-only) | 17 advisories: 1 critical, 12 high, 4 moderate; not remediated or declared safe for release |
| Destructive/live integration tests | **Not run**; no migration, seed or DB writes |

Docker verification created only local build images `smatch-baseline-backend:local` and `smatch-baseline-matchmaking:local`. No image was pushed and no service was deployed. Runtime smoke containers were removed automatically. Docker build's Prisma generation writes client artifacts inside the image; it does not migrate a database.

The production dependency audit covered the current backend lockfile. It is not a proof of exploitability or a dependency upgrade plan. Review it before a production release; do not run automatic audit fixes as part of this baseline.

## 10. Secrets and remaining setup blockers

Secret inventory (values deliberately not copied):

- `backend/.env`: local database credentials and JWT signing secrets; ignored by Git and excluded from Docker contexts.
- `.env.example`, `backend/.env.example`, `docker-compose.yml`, `backend/prisma/seed.ts`: templates or publicly defined local-demo credentials, not a production secret-distribution mechanism. Preserve files; do not reuse defaults in shared production services.
- No private-key/provider-token pattern was found in the tracked/untracked source scan. Ignored dependency/build directories were not treated as project source. This is a limited pattern scan, not a credential audit guarantee.
- No real `.env` or credential values were edited, committed, copied into handoff docs, or embedded in the verified images.

Read-only `migrate status` on the current Docker database reports:

- `20261027120000_add_match_feedback`
- `20261027120000_smm_36_community_rating`
- `20261027130000_smm_36_rating_history`
- `20261101120000_smm_40_analytics_indexes`

Member 2 owns safe application later, with the existing approved backup/verification process. Do not run migrations/seed just to clear this report. A fresh teammate cannot assume the full live Feedback/Rating feature works against the current database.

Other known issues: default Jest command is red due to the pre-existing empty suite; Flutter strict analyze is nonzero for existing info diagnostics; Android licenses on this machine are incomplete; physical-device API addressing and full cross-service/device E2E were not certified. Five-factor HTTP ranking, AI, OAuth, Finance, live Home data synchronization and other assigned features remain incomplete by design.

## 11. Proposed review, branch and commit plan — do not execute during preparation

1. Team lead reviews the preservation inventory, P0.1 changes and setup-only diff. Decide exactly which existing changes are accepted; do not discard other work as a shortcut.
2. Suggested review branch name: `codex/final-sprint-shared-baseline`. Keep the current branch/history unchanged until lead approval. Because current HEAD equals develop, no rebase is needed for the inspected state.
3. Suggested separate logical commits after approval: preserve the reviewed existing UI/integration/assets first; then `chore: prepare shared final sprint setup and handoff`. Do not commit local env files, generated builds, virtualenvs, ephemeral Swift packages or credentials.
4. Resolve or explicitly accept the failed Jest baseline gate and dependency-audit risk with named owners. Completing real FacilitiesService coverage remains a separately approved Final Sprint task; it was not implemented here.
5. Lead merges the reviewed PR into `develop`, verifies the resulting tree and records the **actual resulting develop commit SHA** as the sole shared baseline. This may be a merge or squash SHA; do not pre-fill an invented SHA now.
6. Each member fetches that published commit and creates an independent branch from the **same exact shared SHA**, for example `feature/final-m1-mobile`, `feature/final-m2-database`, `feature/final-m3-backend`, `feature/final-m4-matchmaking`. Coordinate schema/API contracts through reviewed PRs. Do not automatically rebase another member's branch.

**Recommendation: NO-GO for publishing this candidate as a stable/all-green shared baseline yet.** It is ready for lead review, with common build blockers repaired, but the complete Jest command is red, the current shared DB is behind, dependency risk is unreviewed, and the accepted work has not been committed to an immutable shared SHA. Known unfinished product features themselves remain approved backlog items, not implementation work for this preparation.
