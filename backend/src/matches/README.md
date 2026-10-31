# SMM-34 phase A: Complete Match

`PATCH /matches/:id/complete` requires a valid access token. There is no request
body: host identity comes from the verified JWT, and ADMIN has no host override.
Only the stored host may complete OPEN, FULL or IN_PROGRESS when server time is
at or after endTime. Success is HTTP 200 with the existing manager projection;
Booking and participant data are not changed. Invalid IDs return 400, invalid
authentication 401, non-host 403, absent Match 404 and invalid state/time 409.
Repeated completion returns 409 rather than another successful mutation.

All service mutations of an existing Match or its participants lock the parent
Match row using parameterized SELECT FOR UPDATE inside a ReadCommitted Prisma
transaction. Completion additionally uses a conditional update on id, hostId,
allowed status and endTime. Time edits, cancellation, invitation/request writes,
accept/approve/reject and leaving use the same parent lock, so an older request
cannot commit a roster/time change after completion. OPEN/FULL recalculation has
a write-time status predicate as an additional safeguard. No in-process mutex or
automatic retry is used in production. PostgreSQL transaction failures roll back
the mutation; existing Prisma error sanitization remains in place.

COMPLETED is immutable through these Match APIs; behavior for non-completed
Matches is retained. Open-match aliases delegate to the same guarded service
methods. New Match creation and read endpoints retain their previous behavior.
Feedback was out of scope for phase A; phase B below adds feedback only.

Lifecycle unit/HTTP tests simulate transactions and use mocked Prisma. They cover
overlap, rollback, safe responses and old API paths, but cannot prove real
PostgreSQL locking, cross-process contention, lock timeout or deadlock behavior.
Those require separately authorized database integration tests. Other modules'
existing resource-deletion policies (such as detaching Booking on court deletion)
are not changed by phase A.

## Phase B: Submit Feedback

`POST /matches/:id/feedback` requires a PLAYER access token. Body:
`{ "recipientUserId": 30, "rating": 5, "comment": "Good game" }`.
Recipient ID must be a positive PostgreSQL Int; rating an integer 1–5. Comment
may be omitted (stored as null), or a string up to 500 characters; explicit null
is rejected. Sender identity comes exclusively from the verified JWT.

The Match must be COMPLETED and its endTime reached. Both sender and recipient
must have ACCEPTED participant records; hostId alone does not grant eligibility.
Self-feedback is rejected. The transaction reuses the parent Match FOR UPDATE
lock from phase A and creates only Feedback. A unique constraint on
(matchId, senderUserId, recipientUserId) enforces duplicate prevention.

Success: HTTP 201 with exactly id, matchId, senderUserId, recipientUserId, rating,
comment and createdAt (ISO timestamp in JSON). Invalid input/recipient/self: 400;
invalid authentication: 401; non-PLAYER/non-accepted sender: 403; missing Match:
404; invalid state/time/duplicate or transaction conflict: 409. Storage failures
return a sanitized 500. No automatic retry or community rating calculation.

Migration `20261027120000_add_match_feedback` is prepared, NOT applied. All three
foreign keys use ON DELETE RESTRICT to preserve feedback; existing deletion of
referenced Users/Matches will be blocked. Dũng must review retention/deletion,
relation names, nullable comment semantics and the shared model before SMM-36.
Rating/comment constraints currently live in API/service validation, not SQL
CHECK constraints. Aggregation and RatingHistory remain outside this scope.

Feedback tests use mocked Prisma and simulated transactions. Real PostgreSQL
unique conflicts, rollback and cross-process locking need integration testing
after explicit migration approval. They are not proven by these mock tests.
