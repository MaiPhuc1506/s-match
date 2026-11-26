ALTER TABLE "TimeSlot" ADD COLUMN "hourlyRate" DOUBLE PRECISION, ADD COLUMN "walkInPrice" DOUBLE PRECISION;
CREATE TABLE "FacilityService" (
 "id" SERIAL PRIMARY KEY, "facilityId" INTEGER NOT NULL,
 "name" TEXT NOT NULL, "price" DOUBLE PRECISION NOT NULL, "unit" TEXT NOT NULL,
 "category" TEXT NOT NULL DEFAULT 'BEVERAGE', "sortOrder" INTEGER NOT NULL DEFAULT 0,
 "sourceKey" TEXT NOT NULL,
 CONSTRAINT "FacilityService_facilityId_fkey" FOREIGN KEY ("facilityId") REFERENCES "Facility"("id") ON DELETE CASCADE ON UPDATE CASCADE,
 CONSTRAINT "FacilityService_price_check" CHECK ("price" >= 0)
);
CREATE UNIQUE INDEX "FacilityService_facilityId_sourceKey_key" ON "FacilityService"("facilityId", "sourceKey");
