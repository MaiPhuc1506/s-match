# Original DemoCatalog development seed

This seed copies 10 illustrative Flutter DemoCatalog facilities and 46 indoor courts, plus DemoBookingService's 06:00–22:00 hourly slots and evening price increase. These are fictional demo data, not verified facilities. It requires a pre-existing COURT_OWNER chosen via SMATCH_DEMO_OWNER_EMAIL; it never creates accounts or updates existing rows. Name collisions or changes to previously imported facilities, courts or slots abort the transaction.

Facility and Court cannot represent Flutter's negative demo IDs or local image assets: PostgreSQL generates positive IDs, and Facility has no photos field. DemoCatalog has no phone or additional descriptions. The description marks listings as illustrative. The older SMM-44 seed uses different court counts, names, operating slots, prices and addresses, and is not equivalent.

Take and verify a backup first. Set DATABASE_URL to local smatch_db_migration_test or smatch_db (public schema), and SMATCH_DEMO_OWNER_EMAIL to an existing owner. Run `npx ts-node scripts/seed-original-demo-courts.ts`. It uses a serializable transaction and aborts on conflicts. Do not run the SMM-44 seed against these rows; it would update their fields.
