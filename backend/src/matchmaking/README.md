# SMM-26 Matchmaking Gateway / SMM-30 Recommendation Integration

## Scope and temporary contract

NestJS coordinates PLAYER authentication, backend candidate data, and FastAPI.
The Flutter and CandidateProvider contracts below are **temporary**, pending
confirmation with Phuc/Dung/Phat. No candidate search, PostGIS query, scoring,
ranking, recommendation history or database writes are implemented in the gateway.
Candidate search is supplied by the SMM-28 CandidatesService.
SMM-30 enriches ranked results with a read-only batch PlayerProfile query.

`POST /matchmaking/recommend` requires an access Bearer token and current role
PLAYER. It returns HTTP 200 (including empty results).

Request:

```json
{
  "availableTimeSlots": ["2026-10-20T18:00:00Z"],
  "location": { "latitude": 16, "longitude": 108 },
  "maxDistanceKm": 10,
  "minSkillLevel": 2,
  "maxSkillLevel": 4,
  "playingStyles": ["aggressive"]
}
```

The last three fields are optional; explicit null is invalid. Time slots must
contain a date, time and timezone. Coordinates and numeric values must be finite;
skill bounds are integers 1..5 and minimum cannot exceed maximum when both exist.
Clients cannot submit userId/current_user/candidates or arbitrary extra fields.

Response allowlist:

```json
{
  "matchedUsers": [{
    "userId": "7",
    "matchScore": 85,
    "profile": {
      "fullName": "Example player",
      "nickname": null,
      "avatarUrl": null,
      "skillLevel": "INTERMEDIATE"
    }
  }],
  "totalCandidatesProcessed": 2
}
```

No email, phone, raw profile, coordinates, upstream breakdown or other internal
metadata are exposed. Upstream order/scores are preserved, never recalculated.

## SMM-30 profile enrichment

After FastAPI validates and ranks candidates, the Gateway loads profiles with one
Prisma `playerProfile.findMany` call using `userId IN (...)` and current role
PLAYER. FastAPI user IDs are string representations of `User.id`, never
`PlayerProfile.id`; values must fit a positive PostgreSQL Int. Database rows may
arrive in any order: a map keyed by userId enriches the original ranking.

Only fullName (from User), nickname, avatarUrl and skillLevel are selected for
display. All four keys are present and nullable; missing values remain null.
Deleted profiles and users no longer having role PLAYER are omitted. Results
are not refilled/re-ranked, and totalCandidatesProcessed remains the FastAPI
count, even if every ranked profile has disappeared. Empty candidates or an
empty FastAPI ranking skip the enrichment query. Database lookup failures return
a sanitized 503, not a successful empty result; no retries or writes occur.

`RankedResult` is the internal ID/score contract; `MatchmakingResponseDto` is the
enriched public response. Existing response keys, request DTO, PLAYER access and
FastAPI behavior remain unchanged. Mobile must consume the added profile object;
final Mobile contract discussion is pending. SMM-32 history is outside this task.

## Candidate dependency (Dung)

`DatabaseCandidateProvider` is bound to `CANDIDATE_PROVIDER` in MatchmakingModule.
It calls CandidatesService to search up to 100 nearby players, excluding the
requesting player and candidates with no upcoming availability. The SMM-28
bounding-box query remains capped at 500 rows before exact radius filtering.

Search location, availability, distance, optional skill bounds and styles come
from the validated request. Identity, six skill axes, candidate preferences and
candidate availability come from backend data. A PlayerProfile must already
exist; the adapter does not create or update profiles or save search locations.
Candidates routes are registered through CandidatesModule in AppModule.

`UnavailableCandidateProvider` remains available for failure-path tests but is
not the production binding. An unavailable database still produces HTTP 503;
there is no fake production fallback.

## FastAPI configuration (not written to .env by this change)

- `MATCHMAKING_API_URL`: full HTTP(S) endpoint URL including `/api/v1/match`.
  Required when FastAPI is called; no hard-coded URL fallback. Redirects disabled.
- `MATCHMAKING_TIMEOUT_MS`: integer 1..60000, default 5000. Both Axios timeout
  and an RxJS timeout bound the call. No automatic retries.

The client maps profiles to the existing Python `MatchmakingRequest` in
`matchmaking/app/schemas.py`: current_user and candidates, snake_case fields.
It does not set `limit`; Python retains its existing default. No Top-K interface
or algorithm is introduced by the Gateway. Confirm upstream contract/deployment
URL with Phat before real integration.

An empty provider candidate list returns an empty result/count 0 without HTTP.
A FastAPI no-match result returns an empty list with its processed count.
Dependency failure is never converted to successful empty results.

Errors: 400 invalid input; 401 invalid authentication/session; 403 non-PLAYER;
502 invalid backend candidate data, upstream HTTP failure or malformed response;
503 unavailable candidate provider/configuration/upstream connection;
504 upstream timeout. Raw exception text, payloads, URLs and tokens are not logged.

## Verification and remaining integration

Gateway tests mock Prisma, candidate data and outbound HTTP. They exercise real
controllers, ValidationPipe, RolesGuard, JWT verification and Gateway client.
They do not prove live PostgreSQL, FastAPI or Flutter integration.

The SMM-26/SMM-28 integration tests exercise the actual candidate search, adapter
and FastApiClient with mocked database/HTTP boundaries, and boot AppModule to
check dependency injection and route registration. Live FastAPI/Flutter behavior
and PostgreSQL concurrency still require deployment-level verification.
