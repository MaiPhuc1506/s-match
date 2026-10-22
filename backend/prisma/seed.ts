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

  const demoCourts = [
    {
      id: 1,
      name: 'Sân 1 (Indoor VIP)',
      courtType: 'INDOOR',
      slots: [
        { dayOfWeek: 1, startTime: '06:00', endTime: '08:00', price: 160000 },
        { dayOfWeek: 1, startTime: '08:00', endTime: '10:00', price: 180000 },
        { dayOfWeek: 1, startTime: '18:00', endTime: '20:00', price: 240000 },
        { dayOfWeek: 3, startTime: '18:00', endTime: '20:00', price: 240000 },
        { dayOfWeek: 5, startTime: '18:00', endTime: '20:00', price: 240000 },
        { dayOfWeek: 6, startTime: '08:00', endTime: '10:00', price: 200000 },
        { dayOfWeek: 6, startTime: '16:00', endTime: '18:00', price: 220000 },
        { dayOfWeek: 0, startTime: '08:00', endTime: '10:00', price: 220000 },
        { dayOfWeek: 0, startTime: '18:00', endTime: '20:00', price: 260000 },
      ],
    },
    {
      id: 2,
      name: 'Sân 2 (Indoor Chuẩn)',
      courtType: 'INDOOR',
      slots: [
        { dayOfWeek: 1, startTime: '08:00', endTime: '10:00', price: 170000 },
        { dayOfWeek: 1, startTime: '17:00', endTime: '19:00', price: 220000 },
        { dayOfWeek: 2, startTime: '18:00', endTime: '20:00', price: 220000 },
        { dayOfWeek: 4, startTime: '18:00', endTime: '20:00', price: 220000 },
        { dayOfWeek: 6, startTime: '08:00', endTime: '10:00', price: 190000 },
        { dayOfWeek: 6, startTime: '14:00', endTime: '16:00', price: 200000 },
        { dayOfWeek: 0, startTime: '09:00', endTime: '11:00', price: 230000 },
      ],
    },
    {
      id: 3,
      name: 'Sân 3 (Outdoor)',
      courtType: 'OUTDOOR',
      slots: [
        { dayOfWeek: 1, startTime: '06:00', endTime: '08:00', price: 140000 },
        { dayOfWeek: 1, startTime: '16:00', endTime: '18:00', price: 180000 },
        { dayOfWeek: 3, startTime: '16:00', endTime: '18:00', price: 180000 },
        { dayOfWeek: 5, startTime: '16:00', endTime: '18:00', price: 180000 },
        { dayOfWeek: 6, startTime: '07:00', endTime: '09:00', price: 160000 },
        { dayOfWeek: 6, startTime: '17:00', endTime: '19:00', price: 190000 },
        { dayOfWeek: 0, startTime: '07:00', endTime: '09:00', price: 170000 },
        { dayOfWeek: 0, startTime: '16:00', endTime: '18:00', price: 200000 },
      ],
    },
    {
      id: 4,
      name: 'Sân 4 (Indoor Thi Đấu)',
      courtType: 'INDOOR',
      slots: [
        { dayOfWeek: 1, startTime: '18:00', endTime: '20:00', price: 250000 },
        { dayOfWeek: 2, startTime: '18:00', endTime: '20:00', price: 250000 },
        { dayOfWeek: 4, startTime: '18:00', endTime: '20:00', price: 250000 },
        { dayOfWeek: 6, startTime: '08:00', endTime: '10:00', price: 220000 },
        { dayOfWeek: 6, startTime: '18:00', endTime: '20:00', price: 260000 },
        { dayOfWeek: 0, startTime: '08:00', endTime: '10:00', price: 240000 },
        { dayOfWeek: 0, startTime: '18:00', endTime: '21:00', price: 300000 },
      ],
    },
  ];

  for (const c of demoCourts) {
    const court = await (prisma as any).court.upsert({
      where: { id: c.id },
      update: { name: c.name, courtType: c.courtType, facilityId: facility.id },
      create: { id: c.id, facilityId: facility.id, name: c.name, courtType: c.courtType },
    });

    for (const slot of c.slots) {
      await (prisma as any).timeSlot.upsert({
        where: {
          courtId_dayOfWeek_startTime: {
            courtId: court.id,
            dayOfWeek: slot.dayOfWeek,
            startTime: slot.startTime,
          },
        },
        update: { price: slot.price, endTime: slot.endTime },
        create: { courtId: court.id, ...slot },
      });
    }
  }

  // 6. Seed SMM-28 demo data (vị trí + ứng viên quanh Đà Nẵng để test Geo Search / Matchmaking)
  await (prisma as any).playerProfile.update({
    where: { userId: player.id },
    data: { latitude: 16.047079, longitude: 108.20623, locationUpdatedAt: new Date() },
  });

  const demoCandidates = [
    { email: 'player2@smatch.dev', name: 'Demo Player 2', lat: 16.0544, lon: 108.2022, skill: [4.0, 3.5, 4.0, 3.0, 3.5, 3.5], style: 'DOUBLES' },
    { email: 'player3@smatch.dev', name: 'Demo Player 3', lat: 16.0678, lon: 108.2208, skill: [3.0, 4.0, 3.0, 3.5, 3.5, 3.0], style: 'SINGLES' },
    { email: 'player4@smatch.dev', name: 'Demo Player 4 (xa)', lat: 15.8801, lon: 108.3380, skill: [4.0, 4.0, 4.0, 4.0, 4.0, 4.0], style: 'DOUBLES' },
  ];

  for (const c of demoCandidates) {
    const user = await prisma.user.upsert({
      where: { email: c.email },
      update: { password: passwordHash },
      create: {
        email: c.email,
        password: passwordHash,
        fullName: c.name,
        roleId: roleMap[RoleName.PLAYER],
      },
    });

    const profile = await (prisma as any).playerProfile.upsert({
      where: { userId: user.id },
      update: { latitude: c.lat, longitude: c.lon, locationUpdatedAt: new Date() },
      create: {
        userId: user.id,
        nickname: c.name,
        skillLevel: 'INTERMEDIATE',
        latitude: c.lat,
        longitude: c.lon,
        locationUpdatedAt: new Date(),
      },
    });

    const [smash, defense, netPlay, stamina, footwork, serve] = c.skill;
    await (prisma as any).skill.upsert({
      where: { playerProfileId: profile.id },
      update: {},
      create: { playerProfileId: profile.id, smash, defense, netPlay, stamina, footwork, serve },
    });

    await (prisma as any).playingPreference.upsert({
      where: { userId: user.id },
      update: {},
      create: {
        userId: user.id,
        preferredMode: c.style,
        purpose: 'CASUAL',
        minSkillLevel: 2,
        maxSkillLevel: 5,
        maxDistanceKm: 15,
      },
    });

    // Cùng khung giờ rảnh với player demo (Thứ 2 18:00, Thứ 7 08:00) để qua bộ lọc thời gian
    for (const slot of [
      { dayOfWeek: 1, startTime: '18:00', endTime: '21:00' },
      { dayOfWeek: 6, startTime: '08:00', endTime: '11:00' },
    ]) {
      await (prisma as any).availability.upsert({
        where: { userId_dayOfWeek_startTime: { userId: user.id, dayOfWeek: slot.dayOfWeek, startTime: slot.startTime } },
        update: {},
        create: { userId: user.id, ...slot },
      });
    }
  }

  try {
    await prisma.$executeRawUnsafe(
      `SELECT setval(pg_get_serial_sequence('"Court"', 'id'), coalesce(max(id), 1)) FROM "Court";`,
    );
    await prisma.$executeRawUnsafe(
      `SELECT setval(pg_get_serial_sequence('"TimeSlot"', 'id'), coalesce(max(id), 1)) FROM "TimeSlot";`,
    );
  } catch (err) {
    // Non-fatal if sequences don't exist yet
  }

  console.log('Seed completed:', {
    admin: admin.email,
    owner: owner.email,
    player: player.email,
    facilityId: facility.id,
    courtsCount: demoCourts.length,
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