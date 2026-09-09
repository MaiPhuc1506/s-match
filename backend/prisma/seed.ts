import { PrismaClient, RoleName } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  // 1. Seed roles
  const roles = await Promise.all(
    Object.values(RoleName).map((name) =>
      prisma.role.upsert({
        where: { name },
        update: {},
        create: { name },
      }),
    ),
  );
  const roleMap = Object.fromEntries(roles.map((r) => [r.name, r.id]));

  // 2. Seed demo users (idempotent)
  const passwordHash = await bcrypt.hash('Password123!', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@smatch.dev' },
    update: {},
    create: {
      email: 'admin@smatch.dev',
      password: passwordHash,
      fullName: 'System Admin',
      roleId: roleMap[RoleName.ADMIN],
    },
  });

  const owner = await prisma.user.upsert({
    where: { email: 'owner@smatch.dev' },
    update: {},
    create: {
      email: 'owner@smatch.dev',
      password: passwordHash,
      fullName: 'Demo Court Owner',
      roleId: roleMap[RoleName.COURT_OWNER],
    },
  });

  const player = await prisma.user.upsert({
    where: { email: 'player@smatch.dev' },
    update: {},
    create: {
      email: 'player@smatch.dev',
      password: passwordHash,
      fullName: 'Demo Player',
      roleId: roleMap[RoleName.PLAYER],
    },
  });

  console.log('Seed completed:', {
    admin: admin.email,
    owner: owner.email,
    player: player.email,
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
