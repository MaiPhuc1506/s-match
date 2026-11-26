# Core integration rules

- An assessment is valid only when all six stored axes are finite and within
  1–5. Its exact arithmetic mean is the numeric score; formatting alone rounds
  it. Category buckets follow the existing 1–2, 3–4, 5 options: `[1,3)`,
  `[3,5)`, and `5`. Missing assessment retains the stored category but has no
  numeric score or live radar polygon.
- Map is read-only proximity discovery from the saved location. It requires
  candidate consent; its visible category filter uses the effective category
  and does not assert availability. General recommendations use explicit
  search filters, not saved optional skill bounds as hard gates. Discover
  filters match requirements by the numeric level explicitly selected in the UI;
  it does not infer that selection from a player profile.
- Host Nearby starts with a future OPEN match and uses the host's saved
  location, consent, a 5 km radius, common weekly availability start slots,
  and the match's numeric range. A full 1–5 range is unrestricted, including
  unassessed players; a narrower range requires an assessment. Existing
  accepted, invited or requested users are excluded. The write rechecks
  eligibility under the match lock. Private invitations are direct, not a
  substitute for location-based discovery.
- `POST /ratings` is the mobile history and reliability source. The legacy
  `/matches/:id/feedback` endpoint retains independent raw rows and does not
  feed community rating. Both unlock after valid completion, without waiting
  for scheduled end; community ratings retain their 14-day upper window.
  Neither writes assessment dimensions or the profile category.
