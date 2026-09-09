# SMM-8 — User Database & Backend Connection

Scope: Sprint 1, one of four Sprint 1 items (alongside SMM-5 Mobile App Setup,
SMM-6 Authentication Backend, SMM-7 Matchmaking Service Setup — **not**
included in this file set).

## What's here

- `backend/prisma/schema.prisma` — `Role` and `User` tables only.
- `backend/prisma/seed.ts` — seeds the 3 roles (ADMIN, COURT_OWNER, PLAYER)
  and one demo user per role (password `Password123!` for all).
- `backend/src/prisma/` — `PrismaService` / `PrismaModule`, the DB connection
  layer every other module will plug into.
- `backend/src/users/` — `UsersService` (`findByEmail`, `findById`, `findAll`,
  `createUser`) and `UsersController` exposing `GET /users` and `GET /users/:id`.
  These endpoints are **unprotected** on purpose — Auth (SMM-6) hasn't been
  merged into this file set yet.
- `database/init/001_init_extensions.sql` — enables the PostGIS extension on
  first Postgres startup (needed later for court/player location features).
- `docker-compose.yml` — only the `postgres` and `backend` services. `redis`
  and `matchmaking` are left out because those belong to SMM-6/SMM-7.

## What's intentionally NOT here

- Auth endpoints, JWT, guards, RBAC (`SMM-6`).
- Matchmaking FastAPI service (`SMM-7`) — `matchmaking/` is empty.
- Flutter mobile app (`SMM-5`) — `mobile/` is empty.
- Any table/module for Court, Booking, Open Match, or Player Profile —
  those are later-sprint tickets and should add their own Prisma models to
  `schema.prisma` and their own NestJS modules when that work starts.

## Running it

```bash
cd backend
cp .env.example .env   # adjust DATABASE_URL if not using Docker
npm install
npm run db:migrate
npm run db:seed
npm run start:dev
```

Or with Docker:

```bash
docker compose up --build postgres backend
```

- API: http://localhost:3000
- Swagger: http://localhost:3000/docs
