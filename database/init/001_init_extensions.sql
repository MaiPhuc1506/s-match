-- Runs automatically on first Postgres container startup (docker-entrypoint-initdb.d).
-- Enables PostGIS so CourtFacility.latitude/longitude can later be upgraded
-- to a geography column for "find courts near me" queries.
CREATE EXTENSION IF NOT EXISTS postgis;
