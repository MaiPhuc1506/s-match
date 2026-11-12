/* eslint-disable no-console */
// SMM-44 — Rebuild the database from clean migrations and verify it.
//
// Dựng lại một database TẠM THỜI (mặc định: smatch_clean_verify) từ đầu bằng `prisma migrate deploy`,
// rồi: kiểm tra drift -> seed 2 lần (kiểm tra idempotent) -> chạy bộ test DB (constraints,
// double-booking, seed data, PostGIS nếu có) -> tuỳ chọn chạy luôn test API booking thật.
//
// AN TOÀN: script chỉ DROP/CREATE database có tên chứa "verify", "test", "tmp" hoặc "scratch" và
// KHÁC database trong DATABASE_URL. Nó không bao giờ chạy `migrate reset` và không đụng DB dùng chung.
//
// Cách chạy (trong thư mục backend):
//   npm run db:verify:clean
//   npm run db:verify:clean -- --with-api       # chạy thêm bookings.integration.live.spec.ts
//   npm run db:verify:clean -- --db smatch_verify_2 --drop
//
// Biến môi trường:
//   SMM44_ADMIN_URL  URL tới server (DB bất kỳ, ví dụ .../postgres) dùng để CREATE/DROP DATABASE.
//                    Mặc định lấy DATABASE_URL. Dùng port 5434 nếu chạy docker-compose.smm44.yml.

import 'dotenv/config';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { PrismaClient } from '@prisma/client';

const backendDir = join(__dirname, '..');
const args = process.argv.slice(2);
const flag = (name: string) => args.includes(name);
const option = (name: string, fallback: string) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const targetDb = option('--db', 'smatch_clean_verify');
const withApi = flag('--with-api');
const dropAfter = flag('--drop');

type StepResult = { step: string; ok: boolean; note?: string };
const results: StepResult[] = [];
const record = (step: string, ok: boolean, note?: string) => {
  results.push({ step, ok, note });
  console.log(`${ok ? '✔' : '✘'} ${step}${note ? ` — ${note}` : ''}`);
  return ok;
};

function fail(message: string): never {
  console.error(`\n✘ ${message}`);
  process.exit(1);
}

// --- Guard rails -----------------------------------------------------------------------------
const sourceUrl = process.env.SMM44_ADMIN_URL ?? process.env.DATABASE_URL;
if (!sourceUrl) fail('Thiếu DATABASE_URL (hoặc SMM44_ADMIN_URL).');
if (!/^[A-Za-z0-9_]+$/.test(targetDb)) fail(`Tên database không hợp lệ: ${targetDb}`);
if (!/(verify|test|tmp|scratch)/i.test(targetDb)) {
  fail(`Từ chối thao tác trên "${targetDb}": tên database tạm phải chứa verify/test/tmp/scratch.`);
}

const base = new URL(sourceUrl);
const currentDb = decodeURIComponent(base.pathname.replace(/^\//, ''));
if (currentDb === targetDb) fail(`"${targetDb}" trùng database trong URL hiện tại — từ chối.`);

const adminUrl = new URL(sourceUrl);
adminUrl.pathname = '/postgres';
const targetUrl = new URL(sourceUrl);
targetUrl.pathname = `/${targetDb}`;

const prismaCli = join(backendDir, 'node_modules', 'prisma', 'build', 'index.js');
const tsNodeBin = join(backendDir, 'node_modules', 'ts-node', 'dist', 'bin.js');
const jestBin = join(backendDir, 'node_modules', 'jest', 'bin', 'jest.js');

function run(label: string, cliArgs: string[], extraEnv: NodeJS.ProcessEnv = {}): number {
  console.log(`\n▶ ${label}`);
  const r = spawnSync(process.execPath, cliArgs, {
    cwd: backendDir,
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: targetUrl.toString(), ...extraEnv },
  });
  return r.status ?? 1;
}

const COUNT_TABLES = [
  'User', 'PlayerProfile', 'Skill', 'PlayingPreference', 'Availability',
  'Facility', 'Court', 'TimeSlot', 'OperatingHours', 'Booking', 'Match', 'MatchParticipant',
] as const;

async function snapshot(): Promise<Record<string, number>> {
  const client = new PrismaClient({ datasources: { db: { url: targetUrl.toString() } } });
  try {
    const out: Record<string, number> = {};
    for (const table of COUNT_TABLES) {
      const rows = await client.$queryRawUnsafe<{ n: bigint }[]>(`SELECT count(*) AS n FROM "${table}"`);
      out[table] = Number(rows[0].n);
    }
    return out;
  } finally {
    await client.$disconnect();
  }
}

async function main() {
  console.log(`SMM-44 clean rebuild\n  server : ${adminUrl.host}\n  target : ${targetDb}\n`);

  // 1. Drop + create database tạm
  const admin = new PrismaClient({ datasources: { db: { url: adminUrl.toString() } } });
  try {
    await admin.$executeRawUnsafe(`DROP DATABASE IF EXISTS "${targetDb}" WITH (FORCE)`);
    await admin.$executeRawUnsafe(`CREATE DATABASE "${targetDb}"`);
    record(`Create empty database ${targetDb}`, true);
  } catch (e) {
    record(`Create empty database ${targetDb}`, false, (e as Error).message.split('\n').pop());
    await admin.$disconnect();
    return finish();
  }
  await admin.$disconnect();

  // 2. Apply every migration from scratch
  if (!record('prisma migrate deploy (all migrations from zero)', run('prisma migrate deploy', [prismaCli, 'migrate', 'deploy']) === 0)) {
    return finish();
  }
  record('prisma migrate status = up to date', run('prisma migrate status', [prismaCli, 'migrate', 'status']) === 0);

  // 3. Drift: schema.prisma vs database. Exit code 2 = còn khác biệt. (CHECK/EXCLUDE không nằm trong schema.prisma;
  //    nếu Prisma báo chênh lệch chỉ ở "Booking_no_overlap_excl" thì đó là điều kiện đã biết — xem tài liệu.)
  const drift = run('prisma migrate diff (database vs schema.prisma)', [
    prismaCli, 'migrate', 'diff',
    '--from-url', targetUrl.toString(),
    '--to-schema-datamodel', 'prisma/schema.prisma',
    '--exit-code',
  ]);
  record('No schema drift between migrations and schema.prisma', drift === 0, drift === 0 ? undefined : 'xem output phía trên (không chặn các bước sau)');

  // 4. PostGIS (tuỳ chọn): chỉ bật được khi server dùng image postgis/postgis
  let postgis = false;
  const probe = new PrismaClient({ datasources: { db: { url: targetUrl.toString() } } });
  try {
    await probe.$executeRawUnsafe('CREATE EXTENSION IF NOT EXISTS postgis');
    postgis = true;
    record('PostGIS extension available', true);
  } catch {
    // Không phải lỗi: server Postgres thường (postgres:16-alpine) không có PostGIS.
    console.log('⚠ PostGIS không có trên server này — các test PostGIS sẽ bị skip (dùng docker-compose.smm44.yml để bật).');
  } finally {
    await probe.$disconnect();
  }

  // 5. Seed (2 lần) + kiểm tra idempotent
  const seedOk = () =>
    run('seed (prisma/seed.ts)', [tsNodeBin, 'prisma/seed.ts']) === 0 &&
    run('seed (prisma/seed-smm44.ts)', [tsNodeBin, 'prisma/seed-smm44.ts']) === 0;

  if (!record('Seed run #1', seedOk())) return finish();
  const first = await snapshot();
  if (!record('Seed run #2 (idempotency)', seedOk())) return finish();
  const second = await snapshot();
  const changed = COUNT_TABLES.filter((t) => first[t] !== second[t]);
  record(
    'Seed is idempotent (row counts unchanged after 2nd run)',
    changed.length === 0,
    changed.length ? changed.map((t) => `${t}: ${first[t]} -> ${second[t]}`).join(', ') : JSON.stringify(second),
  );

  // 6. Test DB trực tiếp
  const dbSpec = run('DB integrity tests (constraints, double-booking, seed data, PostGIS)', [
    jestBin, '--runInBand', 'src/database/smm44-db-integrity.live.spec.ts',
  ], { RUN_DB_LIVE: '1', ...(postgis ? { SMM44_POSTGIS: '1' } : {}) });
  record('DB integrity spec', dbSpec === 0, postgis ? 'PostGIS: included' : 'PostGIS: skipped');

  // 7. Test API booking thật (đã có sẵn từ P0.1) chạy trên DB sạch
  if (withApi) {
    const api = run('Booking API integration (real DB, auth, row locks)', [
      jestBin, '--runInBand', 'src/bookings/bookings.integration.live.spec.ts',
    ], { RUN_BOOKING_LIVE: '1' });
    record('Booking API integration spec', api === 0);
  } else {
    console.log('\nℹ Bỏ qua test API booking (thêm --with-api để chạy).');
  }

  if (dropAfter) {
    const cleaner = new PrismaClient({ datasources: { db: { url: adminUrl.toString() } } });
    try {
      await cleaner.$executeRawUnsafe(`DROP DATABASE IF EXISTS "${targetDb}" WITH (FORCE)`);
      console.log(`\nDropped ${targetDb}.`);
    } finally {
      await cleaner.$disconnect();
    }
  } else {
    console.log(`\nDatabase "${targetDb}" được giữ lại để kiểm tra bằng Prisma Studio / psql. Dùng --drop để xoá sau khi chạy.`);
  }

  finish();
}

function finish(): never {
  console.log('\n===== SMM-44 summary =====');
  for (const r of results) console.log(`${r.ok ? 'PASS' : 'FAIL'}  ${r.step}${r.note ? `  (${r.note})` : ''}`);
  const failed = results.filter((r) => !r.ok).length;
  console.log(`\n${failed === 0 ? 'ALL CHECKS PASSED' : `${failed} CHECK(S) FAILED`}`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
