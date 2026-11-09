# S-Match Mobile

S-Match is a cross-platform mobile system for badminton court management,
booking, community player profiles, smart matchmaking, and post-match feedback.

## Technology Stack

- Mobile: Flutter + Dart
- Backend: NestJS + TypeScript
- Matchmaking: Python + FastAPI
- Database: PostgreSQL (the current Compose setup does not provision PostGIS)
- Container: Docker + Docker Compose

## Project Structure

- `mobile/` — Flutter mobile application
- `backend/` — NestJS backend
- `matchmaking/` — Python/FastAPI matchmaking service
- `database/` — PostgreSQL/PostGIS resources
- `docs/` — Project documentation

## Shared Final Sprint baseline

Start with [Shared baseline setup and handoff](docs/baseline/SHARED-FINAL-SPRINT-BASELINE.md).
It records the current commit, setup commands, Demo/Live boundaries, existing API
contracts, test results, known blockers, and the four-member branching plan.
