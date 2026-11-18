# Local schedule demo

`npx ts-node scripts/seed-local-schedule-demo.ts` is restricted to
`localhost`/`127.0.0.1`, database `smatch_db`, schema `public`. It verifies
the ten catalog identities and uses the same court row locks as booking
creation. Back up the database before running it.

`npx ts-node scripts/extend-local-demo-hours.ts` sets these local facilities
to 05:00–23:00 and adds slots only for the newly opened periods. The added
periods use the nearest existing illustrative tariff. Existing slots, locks,
booking amounts and booking records are retained. The catalog reflects the
new hours; these rates are still sample data, not verified business prices.

The booking seed caps local closing hours at 23:00 and adds two labelled,
confirmed sample bookings per facility
per Vietnam calendar day, for today and the next six days. Today's sample
bookings may already be in the past: they represent historical demo bookings,
not newly bookable times. Slots and amounts come from the database; conflicts
are skipped. The script never changes existing bookings and is idempotent for
already-seeded days. Run it again later to extend the seven-day demo window;
old records are not automatically removed.

The synthetic user is `schedule-demo@local.invalid`; its password is random.
These are actual local bookings, so they occupy slots and appear in local
booking/owner data. Do not transfer them to production.
