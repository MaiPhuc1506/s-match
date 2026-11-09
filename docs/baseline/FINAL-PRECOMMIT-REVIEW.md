# Final baseline pre-commit review — 10/11/2026

**Assessment: CONDITIONAL GO for a private DEVELOPMENT baseline, not a production release.** This is a proposal awaiting team-lead approval, not authorization to write Git or deploy a shared service.

## 1. Exact review boundary

- Branch remains `feature/SMM-41-FinalIntegrationTestingRelease`.
- HEAD, local develop and read-only verified remote develop: `4090d678b7a9ef2d59521d811e8e44fbbcd872eb`; divergence 0/0.
- Reviewed **134 pre-existing candidate files**: 77 modified tracked files and 57 untracked files. Reviewed text diffs/source, tests, import/asset dependencies, configuration, audit documents, SVG XML and decoded PNG assets. Large layout-only diffs were also compared with whitespace ignored.
- This review adds **four documentation/manifest files only**, making the proposed set **138 paths**. No existing file, source, dependency, schema, migration, seed or application behavior was modified.
- No branch switch/create, stage, commit, push, merge, fetch/ref update, reset, clean, stash or rebase. No migrations, seed, destructive integration tests, advisory exploit probes or dependency upgrades.
- A future baseline commit SHA does not exist yet. Do not substitute the unchanged HEAD for the uncommitted reviewed candidate.

## 2. Classification of every file

[PRECOMMIT-CLASSIFICATION.tsv](PRECOMMIT-CLASSIFICATION.tsv) contains one row per proposed file with its exact path, classification, logical commit group and reason. Every original candidate is assigned once; no wildcard directory is used as a commit specification.

| Classification | Files in proposed commits | Meaning |
| --- | ---: | --- |
| A | 86 | Scoped completed implementation, UI/assets, versioned dependency lock or regression coverage to preserve |
| A + F | 30 | Coherent existing implementation/scaffold with an explicitly incomplete live workflow or manual-QA/lead acceptance gate |
| B | 8 | Shared setup/build configuration |
| C | 8 | Current handoff/report/manifests and README |
| C + F | 6 | Historical audit/backlog reports needing contextual lead review; not current acceptance evidence |
| D | 0 | No generated/local artifact is in the proposed set; exclusions below |
| E | 0 | No real environment file/key/token is in the proposed set; exclusions below |

A + F is not a declaration that the feature is complete. The file is proposed only as an intentionally incomplete but executable development scaffold, subject to explicit lead acceptance. Do not selectively drop such a Dart file while keeping its importers.

### A — scoped work verified for preservation

- **Booking P0.1:** backend ownership/identity checks, Vietnam dates, configured slot prices, row-lock transaction, overlap/availability, Player history and Owner booking feed are paired with tests and the new `booking-time.ts` helper. No Prisma change is required by these deltas. Live tests remain opt-in and can write/delete their own fixtures if explicitly enabled; they were not run in this review.
- **UI/motion:** shared motion helper, wrapping widgets, styling and associated tests form one dependency chain. Preserving only the screen diffs would break imports.
- **Assets/dependencies:** 20 new PNGs decoded successfully and were visually reviewed; 11 candidate SVGs parsed without script/external-image references. PNGs have no EXIF records. These are source assets, not build output. Their demo labeling does not certify real venue, coach or shop identity.
- **Recommendation display:** nullable scores support discovery previews without inventing compatibility; actual API score validation remains unchanged. Model, widget and detail changes must be committed together.
- **Tests:** backend implementations and tests are included together. Native-layer test changes replace assertions about former Flutter overlays with fake-native source/layer/interaction assertions. They do not prove real-device gesture behavior.

### F — lead acceptance gates and known incomplete behavior

1. **Player landing changes:** normal Player welcome, Dev Hub login and Home navigation now enter the new demo Home/catalogue. This is a functional routing change, not just cosmetic motion. Accept this as a labelled development landing page or hold the coherent UI set for a separate decision. It is not the completed live Home data task (`TASK-M1-02`).
2. **Owner detail mixes a real summary with preview fields:** live Owner cards can open `OwnerBookingDetailScreen`, which still contains a fixed date, fixed sample phone and sample photograph. It explicitly labels itself preview and does not call/contact/mutate live data. Accept only as a read-only placeholder; real Owner details/2D schedule remain Member 1 work. Do not claim P0.1 completed all Owner views end-to-end.
3. **Discovery privacy/markers:** live player discovery deliberately ignores raw backend coordinates and does not populate public-area markers from the current API. The new native player-layer helper renders only permitted public areas. Real markers/consent/availableNow require the existing Member 2/3 contracts; raw coordinates still need backend privacy review. Use synthetic development users only.
4. **Feedback:** the new review text, tags, dates and counters are sample-feedback UI and explicitly labelled as not saved. Shared DB migrations and complete live feedback flow are not done. Member 2 owns migration readiness; Members 1/3 own their live integration/E2E pieces.
5. **Match/invitation/recommendation actions:** motion/navigation and honest preview changes are executable, but existing mock/live gaps and direct recommended-player invitations are not completed by this diff. Member 1/3 backlog remains applicable; five-factor HTTP ranking belongs to Member 4.
6. **Simulator adapter:** native pinch support is gated to Simulator, while Dart installation is debug-gated. Native iOS build passed during preparation, but widget/fake-native tests do not replace manual gesture E2E. Member 1 owns that verification.
7. **Historical documentation:** six older reports/backlogs contain superseded snapshots/claims. Four contain **53 machine-specific local links**. Keep them as dated history, not portable setup or current test authority. The canonical handoff, execution backlog and this review must be distinguished; the lead should explicitly accept archived reports or request a later docs-only cleanup. This review does not rewrite them.

## 3. Commit completeness and dependency checks

Static inspection of the intended tree (HEAD files plus the exact manifests) checked **602 project import references** and **197 literal asset references** with no unresolved path outside the proposed tree. Dart package-URI resolution was checked for the navigation import that superficially appears to escape the lib directory; it resolves within `package:mobile` and is not a missing file.

Required atomic file relationships:

| Relationship | Why it must stay together |
| --- | --- |
| `app_motion_widgets.dart` + all changed importers + motion tests | Otherwise auth/facility/booking/match/recommendation screens cannot resolve new widgets |
| Map widget + both `native_*_layers.dart` helpers + iOS adapter + map test/fake-platform changes | Native marker/camera/gesture behavior and test contracts changed together |
| Welcome/Dev Hub/bottom navigation + all eight `player_experience` modules + assets | Import and route graph reaches Home, catalogue, detail pages and session-only demo bookings |
| `pubspec.yaml` + `pubspec.lock` + new shop screen | `url_launcher` is used by source; the application lock and platform package entries are required, not disposable generated files |
| All three Sprint 10 asset directories + catalogues and widgets | Asset declarations alone do not include file contents in Git; all 20 PNG and 8 icon SVG paths must be included |
| Owner calendar/chevron SVGs + dashboard asset map | New asset names are runtime references |
| Booking service/DTO/controller + availability/operating-hours changes + `booking-time.ts` + tests | They share timezone, facility/court validation and pricing/occupancy contracts |
| Live booking service/schedule + summary/success/history/detail/flow + demo subclass | Named parameters, `isDemo`, conflict disabling, photos and session-only history changed together |
| Nullable recommendation model + rendering + discovery consumer tests | Unknown-score previews must not be treated as scored recommendations |
| Backend production script + Dockerfile | Both must target `dist/src/main.js` |
| README + handoff + preservation inventory + retained audit references | Do not introduce documentation links without their target files |

No missing Dart imports/assets were found. TypeScript build and the unchanged Prisma schema were verified during preparation; no implementation input changed since those builds. No backend package-lock update is needed because the package edit only corrects a script. Android release readiness and device/LAN base URL configuration remain outside this approval.

## 4. Exact logical commit groups

### Logical group 1 — implementation, UI, source assets and tests: 116 files

Suggested message: `feat: preserve reviewed player UI and booking integration baseline`.

**Exact file list:** [COMMIT-GROUP-1-IMPLEMENTATION.txt](COMMIT-GROUP-1-IMPLEMENTATION.txt).

Includes all nine backend P0.1 source/test paths and the coherent Flutter implementation/assets/dependency/test set. Contains the 30 A + F files only under the explicit development-scaffold acceptance described above. No docs, private files or generated build outputs.

### Logical group 2 — shared setup/build and handoff: 22 files

Suggested message: `chore: prepare shared final sprint setup and review handoff`.

**Exact file list:** [COMMIT-GROUP-2-SETUP-DOCS.txt](COMMIT-GROUP-2-SETUP-DOCS.txt).

Includes eight setup files, README, the seven existing audit reports, the two original baseline documents and these four new review artifacts. The path manifests themselves are included intentionally.

### Safe execution order after approval: group 2, then group 1

The numbers identify logical groups, not required chronological commit order. **Recommend committing setup group 2 first**, then implementation group 1, and reviewing/merging them in one PR. Group 2 supplies the iOS 15.5 prerequisite and corrected backend start commands before the implementation/native changes are consumed. With the requested implementation-first order, an intermediate checkout could reproduce the known SwiftPM 15.0/15.5 build failure; that order is not recommended.

If the lead requires implementation-first history, either move the iOS project setup prerequisite into that implementation commit with a revised exact manifest, or approve one atomic baseline commit containing the full union. Neither alternative has been executed. Do not split individual files/hunks or drop untracked helpers/assets arbitrarily.

The red empty-suite test is inherited from HEAD and remains a documented baseline exception in either order, not a newly broken import/build hidden by this plan.

## 5. Files to exclude — D and E

These are outside both manifests; preserve them locally and do not force-add:

- **E:** `backend/.env`; all real `.env` variants; private keys, signing certificates/keystores, service-account files and provider/API tokens if any are introduced later.
- **D:** `backend/node_modules/`, `backend/dist/`, `matchmaking/.venv/`, `matchmaking/__pycache__/`, `mobile/build/`, `mobile/.dart_tool/`, `mobile/ios/Flutter/ephemeral/`, `mobile/ios/Flutter/Generated.xcconfig`, `mobile/ios/Flutter/flutter_export_environment.sh`; local logs, coverage/build caches and the review's `/private/tmp` files.

The existing real backend env and generated paths were confirmed ignored. Current candidate filenames and text patterns contain no real env file, private-key block, provider-token pattern or literal JWT. This is a scoped static scan, not a guarantee about all future changes. No matched secret values were printed into this report.

Public development defaults/templates already exist in the unchanged seed/Compose/env examples; they are not new private credentials. This plan neither removes those HEAD files nor authorizes their use outside synthetic local development. `pubspec.lock`, authored PNG/SVG assets, the iOS project and source/test helpers must not be misclassified as local/generated output.

## 6. The “17 advisories”: package-level triage, not a blanket production verdict

Fresh read-only `npm audit --omit=dev --json` still reports **17 affected dependency entries**: 1 critical, 12 high, 4 moderate. The response contains **41 distinct advisory URLs** across those entries. Counts include inherited chains; they are not 17 independent exploits or proof that every finding is remotely reachable.

No dependency was upgraded and no exploit payload was sent. Assessment below is source/lockfile/maintainer-advisory analysis, with reachability an inference rather than a penetration-test result.

| Package (locked version) | Audit level | Development-baseline assessment |
| --- | --- | --- |
| `tar` 6.2.1 | Critical | Transitive via bcrypt → node-pre-gyp. Archive extraction risk is credible during installation/build with malicious archives; no application tar-upload/extraction route found. Use trusted packages/artifacts and isolated builds; not alone a reason to prohibit sharing source. |
| `@mapbox/node-pre-gyp` 1.0.11 | High | Inherits tar risk in native dependency installation; not a separate HTTP endpoint. Same build restriction. |
| `body-parser` 1.20.4 | High | **Credible network-facing runtime issue.** Nest's Express adapter installs default JSON/urlencoded parsers, and the compressed-body advisory applies before authentication/routing. Invalid-limit advisory precondition is not observed, but that does not remove the compressed-body risk. Block untrusted exposure of a dev service. |
| `@nestjs/platform-express` 10.4.22 | High | Aggregate of body-parser/multer/core. Treat the parser exposure as real; do not dismiss the whole entry as unused. |
| `multer` 2.0.2 | High | Upload/multipart parsing vulnerabilities; no File/Files/AnyFiles interceptor or upload route found in app source. Reassess before enabling uploads. No demonstrated current route in this review. |
| `file-type` 20.4.1 | Moderate | Malformed-file detection/parsing DoS; no app file-type validator/upload use found. Dormant for current inspected endpoints. |
| `@nestjs/common` 10.4.22 | Moderate | Inherits file-type finding. Same current-reachability limitation. |
| `@nestjs/core` 10.4.22 | Moderate | SSE event-field injection advisory requires user-controlled SSE type/id. No `@Sse` endpoint or SSE bridge found. Aggregate dependencies still tracked separately. |
| `lodash` 4.17.21 | High | Template-import code injection and prototype-mutating APIs need unsafe inputs/sinks. No app `_.template`, dynamic imports options or identified pollution sink found. Not proof of harmlessness; maintain a tracked upgrade task. |
| `@nestjs/config` 3.3.0 | High | Inherits lodash. Configuration is developer-controlled; no dynamic request-to-template bridge found. |
| `js-yaml` 4.1.0 | High | YAML merge/parser complexity/pollution issues. No untrusted YAML loading endpoint found; Swagger document construction is server-owned. |
| `@nestjs/swagger` 8.1.1 | High | Inherits lodash/js-yaml/core findings, not a separately demonstrated exploit. Keep docs private until broader dependency/security review. |
| `follow-redirects` 1.16.0 | High | Credential-header redirect weaknesses require relevant redirected requests/options. Current FastApiClient explicitly uses `maxRedirects: 0`, with configured server-owned target. No custom sensitiveHeaders bridge found. Reassess if networking/OAuth/AI tools add redirect-following calls. |
| `deepmerge-ts` 7.1.5 | High | Advisory needs recursive object graphs, not plain JSON alone. Reached through developer-owned Prisma config; no request-facing deepmerge sink found. |
| `@prisma/config` 6.19.3 | High | Inherits deepmerge config-chain risk; not a separate application API route. |
| `prisma` 6.19.3 | High | CLI/config chain includes the previous finding, even though installed in production dependencies. Do not use untrusted config or run migrations during baseline review. |
| `qs` 6.14.2 | Moderate | Reported conditions include comma-mode parsing and stringify-specific object inputs. No corresponding custom options/calls found in app source; do not equate the entire dependency with a proven current exploit. |

Primary sources and interpretation boundaries:

- The maintainer describes a pre-routing compressed-body process crash in [body-parser GHSA-27r3-jxmh-p828](https://github.com/expressjs/body-parser/security/advisories/GHSA-27r3-jxmh-p828). **Because S-Match uses defaults, public/untrusted reachability is a credible blocker for running a shared exposed backend.** No crash was reproduced deliberately.
- The [node-tar maintainer advisory](https://github.com/isaacs/node-tar/security/advisories/GHSA-34x7-hfp2-rc4v) describes malicious archive hardlink traversal. The API source exposes no such extraction workflow; installation risk remains.
- The [lodash maintainer advisory](https://github.com/lodash/lodash/security/advisories/GHSA-r5fr-rjxr-66jc) requires untrusted template-import keys, which were not found in this app.
- The [follow-redirects maintainer advisory](https://github.com/follow-redirects/follow-redirects/security/advisories/GHSA-mrwp-f3q8-3g9p) describes special custom-header/cross-realm/redirect conditions. The current FastAPI call disables redirects; this is a scoped mitigation, not a universal waiver for the dependency.

**Development decision:** sharing this exact code in a private repository with four trusted developers is conditionally acceptable using synthetic data, private dev credentials and genuinely local/isolated services. The backend binds to `0.0.0.0` today; localhost in a browser URL does not itself restrict listening. The lead must enforce loopback-only publication/network access control (for example loopback Docker port publishing or a verified host firewall) before running it where untrusted callers can reach it. If isolation cannot be enforced, **NO-GO for that exposed shared development server**. Production release remains NO-GO pending dependency remediation/security validation.

## 7. Build/test readiness and known owner assignments

Re-run on 10/11/2026 for the unchanged candidate:

- Flutter: **193/193 widget/unit tests pass**.
- FastAPI: **19/19 tests pass**; existing deprecation warnings remain.
- Backend: **938 pass, 7 skipped**, with **36 suites pass, 2 skipped and 1 failed empty FacilitiesService suite**. No filtering was used to hide it; the two DB-writing live opt-ins were explicitly disabled.
- `git diff --check`: pass. Static dependency/asset membership checks: pass. No new schema/migration/seed changes.

The previous preparation's clean TypeScript build, both Docker image builds/runtime-import checks, both Flutter bundles and native iOS Simulator build remain applicable because their implementation/config inputs are unchanged. They were not all rebuilt during this read-only pre-commit review. Prior `flutter analyze` had 22 info diagnostics, not compile errors; default analyze still needs an explicit baseline-policy decision. Android licenses/device E2E remain unverified gates for the relevant platforms.

| Known exception/incomplete work | Owner / next action after shared baseline |
| --- | --- |
| Empty FacilitiesService test suite makes the default Jest command red | Member 3, existing `TASK-M3-03`; lead must explicitly accept a temporary development baseline exception, not silently skip/add a placeholder |
| Four DB migrations pending; live feedback/rating readiness | Member 2, `TASK-M2-01`, separately approved backup/verification process |
| Live Home/catalogue synchronization, Owner detail/grid, device gestures | Member 1, `TASK-M1-02/03/09` scope coordination; preview detail limitation explicitly accepted or assigned |
| Open Match/invitations, skills, OAuth, AI and Finance gaps | Existing Member 1/2/3 backlog; not implemented by this review |
| Five-factor algorithm not fully wired to active endpoint | Member 4, `TASK-M4-01..04` |
| Dependency triage and safe dev-service exposure | Team lead + Member 3; no upgrade authorized here |
| Historical links/counts | Team lead/docs reviewer; keep dated context or approve a docs-only cleanup |

## 8. Merge and handoff recommendation

- Recommended PR **base: `develop`**, **source: existing `feature/SMM-41-FinalIntegrationTestingRelease`** after approval and the two reviewed logical commits. No new branch is needed for this plan and none was created.
- No migration or seed is included. No branch-history rewrite is needed for the verified 0/0 starting state.
- Lead must approve: the exact manifests, F-scaffold acceptance (especially demo landing/Owner details), the explicit red-test exception with Member 3 ownership, and dev network/credential restrictions.
- After both groups are reviewed and merged, publish the **actual resulting develop SHA**, then all four developers branch from that same SHA. Do not use the old HEAD as if it contained this work, and do not start from a moving branch without recording its commit.
- **CONDITIONAL GO for a DEVELOPMENT baseline** under these conditions. The earlier handoff's NO-GO was for a stable/all-green publication; incomplete Final Sprint tasks and an explicit inherited test exception do not by themselves require completing that sprint before sharing a development starting point.
- **NO-GO for production, public API exposure or a claim of fully live end-to-end completion.** Do not interpret this report as lead approval. All Git write operations remain pending the user's explicit next instruction.
