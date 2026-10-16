# SMM-26 / SMM-28 migration reconciliation

The merged schema retains PlayerProfile location fields and their index,
RefreshSession and User.refreshSessions, and one Court.timeSlots / TimeSlot model.
The remaining TimeSlot model is equivalent to the restore SQL (Prisma defaults
onUpdate to Cascade for this relation).

The migration chain retains:

- `20261014120000_restore_time_slot`
- `20261015000000_smm_28_player_location`
- `20261015120000_add_refresh_session`

`20261015103317_restore_time_slot_table` was removed because it drops the player
location columns/index and attempts to create TimeSlot a second time.

## Existing databases

The local database inspected before this fix had applied only the first five
migrations, through `20260929040649_smm_20_slot_pricing`. The removed migration
had not run there. No migrations were applied to that database by this fix.

Before deploying to another database, inspect `_prisma_migrations` for the removed
migration. If it has already run, retain that environment's migration history and
prepare a forward repair/reconciliation rather than deploying this deletion
unchanged. Re-adding columns cannot restore location data already dropped.

The older `20261006153509_add_match_management` migration drops TimeSlot before
the October 14 migration restores its structure. Back up existing slot data and
plan its restoration before upgrading a database that has not run that migration.

An empty local-only `20261004150043_smm_24_invitation_participation` directory
also caused P3015 and was removed; it contained no tracked migration file.

## Verification

- Prisma validate and generate succeeded.
- Backend build and TypeScript checks succeeded.
- All 24 Jest suites / 591 tests passed, including real AppModule initialization
  and SMM-28 search -> adapter -> gateway -> mocked FastAPI integration.
- All 10 migrations deployed to an isolated disposable PostgreSQL database.
  Prisma diff reported no difference between that database and schema.prisma.
  The disposable database was dropped afterwards.

Set distinct JWT_ACCESS_SECRET / JWT_REFRESH_SECRET values and the full
MATCHMAKING_API_URL in the runtime environment (see ../.env.example). Verification
does not include a live FastAPI server, Flutter, or another team's database.
