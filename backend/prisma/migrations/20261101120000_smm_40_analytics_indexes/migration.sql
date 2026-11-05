-- CreateIndex
CREATE INDEX "Facility_ownerId_idx" ON "Facility"("ownerId");

-- CreateIndex
CREATE INDEX "Court_facilityId_status_idx" ON "Court"("facilityId", "status");

-- CreateIndex
CREATE INDEX "Booking_courtId_status_startTime_idx" ON "Booking"("courtId", "status", "startTime");

-- CreateIndex
CREATE INDEX "Booking_status_startTime_idx" ON "Booking"("status", "startTime");
