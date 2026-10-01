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
    update: { password: passwordHash },
    create: {
      email: 'admin@smatch.dev',
      password: passwordHash,
      fullName: 'System Admin',
      roleId: roleMap[RoleName.ADMIN],
    },
  });

  const owner = await prisma.user.upsert({
    where: { email: 'owner@smatch.dev' },
    update: { password: passwordHash },
    create: {
      email: 'owner@smatch.dev',
      password: passwordHash,
      fullName: 'Demo Court Owner',
      roleId: roleMap[RoleName.COURT_OWNER],
    },
  });

  const player = await prisma.user.upsert({
    where: { email: 'player@smatch.dev' },
    update: { password: passwordHash },
    create: {
      email: 'player@smatch.dev',
      password: passwordHash,
      fullName: 'Demo Player',
      roleId: roleMap[RoleName.PLAYER],
    },
  });

  // 3. Seed SMM-12 demo data (Availability & Preference) for the demo player
  const preferenceModel = prisma as any;
  await preferenceModel.playingPreference.upsert({
    where: { userId: player.id },
    update: {},
    create: {
      userId: player.id,
      preferredMode: 'DOUBLES',
      purpose: 'CASUAL',
      minSkillLevel: 2,
      maxSkillLevel: 4,
      maxDistanceKm: 10,
    },
  });

  await (prisma as any).availability.upsert({
    where: { userId_dayOfWeek_startTime: { userId: player.id, dayOfWeek: 1, startTime: '18:00' } },
    update: {},
    create: { userId: player.id, dayOfWeek: 1, startTime: '18:00', endTime: '21:00' },
  });
  await (prisma as any).availability.upsert({
    where: { userId_dayOfWeek_startTime: { userId: player.id, dayOfWeek: 6, startTime: '08:00' } },
    update: {},
    create: { userId: player.id, dayOfWeek: 6, startTime: '08:00', endTime: '11:00' },
  });

  // 4. Seed SMM-10 & SMM-13 demo data (PlayerProfile & Skill) for the demo player
  const playerProfile = await (prisma as any).playerProfile.upsert({
    where: { userId: player.id },
    update: {},
    create: {
      userId: player.id,
      nickname: 'Siêu Cấp Vip Pro',
      skillLevel: 'INTERMEDIATE',
      bio: 'Giao lưu học hỏi là chính, đập cầu là chủ yếu!',
      gender: 'MALE',
    },
  });

  await (prisma as any).skill.upsert({
    where: { playerProfileId: playerProfile.id },
    update: {},
    create: {
      playerProfileId: playerProfile.id,
      smash: 4.5,
      defense: 3.5,
      netPlay: 4.0,
      stamina: 3.0,
      footwork: 3.5,
      serve: 4.0,
    },
  });

  // 5. Seed SMM-14/16/20 demo data (Facility, Court, OperatingHours, TimeSlot)
  const facility = await (prisma as any).facility.upsert({
    where: { id: 1 },
    update: {},
    create: {
      id: 1,
      ownerId: owner.id,
      name: 'S-Match Demo Badminton Center',
      address: '123 Nguyễn Văn Linh, Đà Nẵng',
      latitude: 16.047079,
      longitude: 108.20623,
      contactPhone: '0900000000',
      description: 'Cơ sở demo dùng để test API',
    },
  });

  for (let dayOfWeek = 0; dayOfWeek <= 6; dayOfWeek += 1) {
    await (prisma as any).operatingHours.upsert({
      where: { facilityId_dayOfWeek: { facilityId: facility.id, dayOfWeek } },
      update: {},
      create: { facilityId: facility.id, dayOfWeek, openTime: '06:00', closeTime: '22:00' },
    });
  }

  const court = await (prisma as any).court.upsert({
    where: { id: 1 },
    update: {},
    create: { id: 1, facilityId: facility.id, name: 'Sân 1', courtType: 'INDOOR' },
  });

  await (prisma as any).timeSlot.upsert({
    where: { courtId_dayOfWeek_startTime: { courtId: court.id, dayOfWeek: 1, startTime: '18:00' } },
    update: {},
    create: { courtId: court.id, dayOfWeek: 1, startTime: '18:00', endTime: '19:00', price: 240000 },
  });
  await (prisma as any).timeSlot.upsert({
    where: { courtId_dayOfWeek_startTime: { courtId: court.id, dayOfWeek: 6, startTime: '08:00' } },
    update: {},
    create: { courtId: court.id, dayOfWeek: 6, startTime: '08:00', endTime: '09:00', price: 200000 },
  });

  console.log('Seed completed:', {
    admin: admin.email,
    owner: owner.email,
    player: player.email,
    facilityId: facility.id,
    courtId: court.id,
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