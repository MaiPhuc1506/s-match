// Explicit local development setup. Run only against the developer's local DB.
require('dotenv').config();
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const bcrypt = require('bcrypt');
const { PrismaClient } = require('@prisma/client');
const connection = new URL(process.env.DATABASE_URL || '');
if (process.env.NODE_ENV !== 'development' || !['localhost', '127.0.0.1', '::1'].includes(connection.hostname) || connection.pathname !== '/smatch_db') {
  throw new Error('This setup only runs against a local development database.');
}
const pairs = [['player@smatch.dev', 'DEV_PLAYER_1_PASSWORD'], ['player2@smatch.dev', 'DEV_PLAYER_2_PASSWORD'], ['player3@smatch.dev', 'DEV_PLAYER_3_PASSWORD']];
const words = ['Badminton', 'Lantern', 'Harbor', 'Jasmine', 'Bamboo', 'Dragonfly', 'Mountain', 'Morning', 'Sunflower', 'Riverbank', 'Moonlight', 'Phoenix'];
const choose = () => words[crypto.randomInt(words.length)];
const makePassword = () => `${choose()}-${choose()}-${choose()}!${crypto.randomInt(100, 1000)}`;
const configPath = path.resolve(__dirname, '../../mobile/.env.dev-quick-login.json');
const db = new PrismaClient();
(async () => {
  const users = await db.user.findMany({ where: { email: { in: pairs.map(([email]) => email) } }, select: { id: true, email: true, role: { select: { name: true } } } });
  if (users.length !== 3 || users.some((u) => u.role.name !== 'PLAYER')) throw new Error('Expected three existing PLAYER accounts; no records changed.');
  let config = {};
  if (fs.existsSync(configPath)) config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const passwords = new Set();
  for (const [, key] of pairs) { let password; do { password = makePassword(); } while (passwords.has(password)); passwords.add(password); config[key] = password; }
  const hashes = await Promise.all(pairs.map(async ([email, key]) => ({ email, password: await bcrypt.hash(config[key], 12) })));
  const temporary = `${configPath}.new`;
  fs.writeFileSync(temporary, JSON.stringify(config, null, 2), { mode: 0o600, flag: 'wx' });
  try {
    await db.$transaction(hashes.map(({ email, password }) => db.user.update({ where: { email }, data: { password }, select: { id: true } })));
    fs.renameSync(temporary, configPath);
  } catch (error) { fs.rmSync(temporary, { force: true }); throw error; }
  console.log('Updated three existing development PLAYER password hashes and protected local debug configuration.');
})().catch((error) => { console.error('Development setup failed:', error.message); process.exitCode = 1; }).finally(() => db.$disconnect());
