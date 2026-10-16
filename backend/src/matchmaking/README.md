# SMM-26 Matchmaking Gateway

## Scope and temporary contract

NestJS coordinates PLAYER authentication, backend candidate data, and FastAPI.
The Flutter and CandidateProvider contracts below are **temporary**, pending
confirmation with Phuc/Dung/Phat. No candidate search, PostGIS query, scoring,
ranking, recommendation history or database writes are implemented here.

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
  "matchedUsers": [{ "userId": "7", "matchScore": 85 }],
  "totalCandidatesProcessed": 2
}
```

No email, phone, raw profile, coordinates, upstream breakdown or other internal
metadata are exposed. Upstream order/scores are preserved, never recalculated.

## Candidate dependency (Dung)

Implement `CandidateProvider.getCandidates(authenticatedUserId, criteria)` and
bind it to `CANDIDATE_PROVIDER` in MatchmakingModule. It must return normalized
`CandidateData`, honor the requested criteria, and supply backend-owned skill
and reliability data. Current-user identity must match the authenticated user.
The six skill dimensions, date/time availability mapping, source of location,
missing-profile handling and API/service endpoint still need confirmation.

**Default production behavior is HTTP 503** until a real provider is bound.
There is no fake production fallback. Never use PlayersService.getMyProfile()
for this adapter without addressing its automatic profile creation side effect.
Do not substitute FastAPI's sample dataset endpoint for backend candidate data.

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

Pending: Phuc confirms Flutter fields/response/status; Dung supplies provider and
mapping; Phat confirms existing FastAPI schema, time semantics, default limit,
scores and error behavior. Only then can Flutter -> NestJS -> FastAPI -> Flutter
be verified end to end with explicit approval. Group 2 PostgreSQL/concurrency
testing remains deferred and is not resumed by this ticket.
