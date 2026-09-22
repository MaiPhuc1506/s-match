/*
  Warnings:

  - The `preferredMode` column on the `PlayingPreference` table would be dropped and recreated. This will lead to data loss if there is data in the column.
  - The `purpose` column on the `PlayingPreference` table would be dropped and recreated. This will lead to data loss if there is data in the column.

*/
-- CreateEnum
CREATE TYPE "MatchMode" AS ENUM ('SINGLES', 'DOUBLES');

-- CreateEnum
CREATE TYPE "MatchPurpose" AS ENUM ('CASUAL', 'TRAINING', 'COMPETITIVE');

-- CreateEnum
CREATE TYPE "CourtStatus" AS ENUM ('ACTIVE', 'MAINTENANCE', 'INACTIVE');

-- AlterTable
ALTER TABLE "PlayingPreference" DROP COLUMN "preferredMode",
ADD COLUMN     "preferredMode" "MatchMode" NOT NULL DEFAULT 'DOUBLES',
DROP COLUMN "purpose",
ADD COLUMN     "purpose" "MatchPurpose" NOT NULL DEFAULT 'CASUAL',
ALTER COLUMN "maxDistanceKm" SET DATA TYPE DOUBLE PRECISION;

-- CreateTable
CREATE TABLE "Skill" (
    "id" SERIAL NOT NULL,
    "playerProfileId" INTEGER NOT NULL,
    "smash" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "defense" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "netPlay" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "stamina" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "footwork" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "serve" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Skill_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Facility" (
    "id" SERIAL NOT NULL,
    "ownerId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "address" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "contactPhone" TEXT,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Facility_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Court" (
    "id" SERIAL NOT NULL,
    "facilityId" INTEGER NOT NULL,
    "name" TEXT NOT NULL,
    "courtType" TEXT DEFAULT 'INDOOR',
    "status" "CourtStatus" NOT NULL DEFAULT 'ACTIVE',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Court_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "OperatingHours" (
    "id" SERIAL NOT NULL,
    "facilityId" INTEGER NOT NULL,
    "dayOfWeek" INTEGER NOT NULL,
    "openTime" TEXT NOT NULL,
    "closeTime" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OperatingHours_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Skill_playerProfileId_key" ON "Skill"("playerProfileId");

-- CreateIndex
CREATE UNIQUE INDEX "OperatingHours_facilityId_dayOfWeek_key" ON "OperatingHours"("facilityId", "dayOfWeek");

-- AddForeignKey
ALTER TABLE "Skill" ADD CONSTRAINT "Skill_playerProfileId_fkey" FOREIGN KEY ("playerProfileId") REFERENCES "PlayerProfile"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Facility" ADD CONSTRAINT "Facility_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Court" ADD CONSTRAINT "Court_facilityId_fkey" FOREIGN KEY ("facilityId") REFERENCES "Facility"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "OperatingHours" ADD CONSTRAINT "OperatingHours_facilityId_fkey" FOREIGN KEY ("facilityId") REFERENCES "Facility"("id") ON DELETE CASCADE ON UPDATE CASCADE;
