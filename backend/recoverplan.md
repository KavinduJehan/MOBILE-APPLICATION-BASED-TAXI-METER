Read [](file:///c%3A/Personal%20Files/Projects/Software%20Project-eng/backend/package.json)

Read [](file:///c%3A/Personal%20Files/Projects/Software%20Project-eng/backend/tests/auth.test.js)

Read [](file:///c%3A/Personal%20Files/Projects/Software%20Project-eng/backend/tests/drivers.test.js)

Here is your honest, prioritized recovery plan. No fluff.

---

## Phase 1 — Fix What's Broken in the Existing Backend

These are bugs and gaps that undermine what already exists. Fix these first before writing a single new line.

**Unit 1.1 — Fix the trip `endTime` bug**
In tripController.js, `endTime` is set to `new Date()` at trip *creation*. It must only be set in `endTrip`. One-line fix. - Done

tripController.js — removed endTime: new Date() from createTrip. It's already set correctly in endTrip.
Trip.js — changed endTime from required: true to optional, since a trip has no end time until it's completed.

**Unit 1.2 — Wire up `requireRole` for admin routes**
`requireRole` middleware exists but is used nowhere. Any "regulator" can currently do nothing different from a driver. This needs to be enforced on admin endpoints once you build them.

controllers/adminController.js — listDrivers, setDriverVerification, getAllTrips
routes/admin.js — all routes gated by protect + requireRole('regulator') via router.use()
app.js — admin routes registered at /api/admin

**Unit 1.3 — Fix QR lookup to not expose raw MongoDB `_id`**
`getDriverByQR` takes `qrToken` directly as a MongoDB `_id`. The QR should encode an opaque token or at minimum validate the ID format before querying.

models/Driver.js — added qrToken: { type: String, unique: true, sparse: true }. sparse: true means the unique index only applies to documents where the field exists, safe for any legacy records.

controllers/authController.js — imports uuidv4 and generates a qrToken at registration time.

controllers/driverController.js — two changes:

updateQRCode now embeds token: driver.qrToken in the QR payload instead of driverId: driver._id
getDriverByQR now does Driver.findOne({ qrToken }) — no MongoDB internals are exposed or queried via the URL
The public URL /api/drivers/qr/:qrToken now only reveals an opaque UUID, not the database structure.

**Unit 1.4 — Implement `isVerified` control**
`isVerified` exists on `Driver` but nothing can set it to `true`. A driver registers and is forever unverified. The `getNearbyDrivers` and `getAreaRates` both filter by `isVerified: true`, meaning they return nothing after registration. This is a live functional bug.

scripts/seedAdmin.js — run once with:

Creates a role: 'regulator' account using credentials from .env. Safe to re-run — it does nothing if the email already exists.

The full isVerified flow now works end-to-end:

Run seed script → regulator account created
Regulator logs in at POST /api/auth/login → gets JWT
Regulator calls PATCH /api/admin/drivers/:id/verify with { "isVerified": true } → driver approved
Approved driver now appears in GET /api/drivers/nearby and GET /api/rates/area

---

## Phase 2 — Build the Admin (Regulator) System

The report claims this. The code has a skeleton (`role: 'regulator'`) but zero implementation.

**Unit 2.1 — Admin route: list all pending drivers**
`GET /api/admin/drivers` — returns drivers where `isVerified: false`, protected by `requireRole('regulator')`.

**Unit 2.2 — Admin route: approve/reject a driver**
`PATCH /api/admin/drivers/:id/verify` — sets `isVerified: true/false`. This unblocks Unit 1.4.

**Unit 2.3 — Admin route: view all trips (oversight)**
`GET /api/admin/trips` — returns all trips across all drivers for monitoring.

**Unit 2.4 — Seed an admin account**
There is no way to create a `regulator` account currently since `register` hardcodes `role: 'driver'`. Add a seeder script or a protected bootstrap endpoint.

---

## Phase 3 — Reconcile the Report's Claims With Reality

Your report makes claims your code cannot back up. You must choose: fix the code to match, or fix the report to match the code. Here's what to do for each:

**Unit 3.1 — Drop the SQLite/offline claim OR implement a bare minimum**
Offline SQLite is the hardest thing in the entire report. The honest move: change the report to say *"offline capability is planned for a future version; the current implementation uses cloud-only MongoDB with the `syncedToCloud` field reserved for the sync mechanism."* This is academically acceptable at interim stage.

**Unit 3.2 — Align model names with report**
The report says "Rate" and "Area" are entities. Your code has them as string fields on `Driver`. Either update the report's data model diagram to reflect reality, or extract them into separate collections. Extracting is overkill — update the report.

**Unit 3.3 — Customer model decision**
Same issue. `customerName` as a string is fine for this system. Update the report's ER diagram to show `customerName` as an attribute of `Trip`, not a separate entity.

---

## Phase 4 — Build the Frontend (Flutter)

This is the largest missing piece. Do it in order:

**Unit 4.1 — Driver screens**
1. Register / Login
2. Dashboard (profile, QR display, rate update)
3. Start Trip / End Trip
4. Trip History + Receipt view

**Unit 4.2 — Customer screens**
1. QR Scanner
2. Driver info display after scan
3. Fare estimate view

**Unit 4.3 — Admin screen (web, not mobile)**
1. Pending driver list
2. Approve/Reject action
3. Basic trip overview table

---

## Phase 5 — Testing and Cleanup

**Unit 5.1 — Add missing test cases**
Tests for `rates` and `trips` exist but check what's actually covered. The admin routes you build in Phase 2 have zero test coverage — write them alongside the code, not after.

**Unit 5.2 — Run all tests and fix failures**
Run `npm test` now. It will likely fail on `getNearbyDrivers` returning empty arrays because no driver is ever `isVerified: true` in tests.

**Unit 5.3 — Environment hardening**
`.env.example` exists which is good. Confirm `JWT_SECRET` is strong, not a placeholder like `"secret"`.

---

## The Honest Priority Order

```
Fix bugs (Phase 1)  →  Admin system (Phase 2)  →  Fix report claims (Phase 3)
→  Flutter Driver screens (Phase 4.1)  →  Flutter Customer screens (Phase 4.2)
→  Admin web screen (Phase 4.3)  →  Tests + cleanup (Phase 5)
```

**Start with Unit 1.4 first** — the `isVerified` bug breaks the most visible features right now and it takes 10 minutes to fix.You've used 50% of your weekly rate limit. Your weekly rate limit will reset on May 4 at 5:30 AM. [Learn More](https://aka.ms/github-copilot-rate-limit-error)





Mapping your Scrum board against what's actually built:

---

## Backend — Missing

| SCRUM | Item | Status |
|---|---|---|
| SCRUM-27/30/31 | Request ride / Receive ride requests / Accept or reject ride | **Not built.** No ride request flow exists. Currently a driver just starts a trip directly — there's no accept/reject handshake between driver and customer |
| SCRUM-38 | Driver income tracking | **Not built.** Trips are stored but there's no `GET /api/trips/income` summary endpoint (total earnings, per day/week) |
| SCRUM-53 | View system reports | **Not built.** No reports endpoint (e.g. total trips, revenue per area, active drivers count) |
| SCRUM-19 | Government verification system | **Out of scope** — no public API exists. Acknowledged |
| SCRUM-45/46/47 | Offline functionality | **Out of scope for now** — `syncedToCloud` field reserved, architecture documented |

---

## Admin UI — Missing

| SCRUM | Item | Status |
|---|---|---|
| SCRUM-52 | Monitor driver rates | **Partially done.** Driver table shows `ratePerKm` but there's no dedicated rate comparison view |
| SCRUM-53 | View system reports | **Not built.** Needs a reports/stats page |

---

## Testing & Deployment — Not Started

| SCRUM | Item |
|---|---|
| SCRUM-56 | Integration testing |
| SCRUM-57 | Performance testing |
| SCRUM-58 | Deployment |
| SCRUM-59 | Documentation |
| SCRUM-66 | Unit testing frontend |

---

## What to do now (backend only, before Flutter)

**Priority 1 — SCRUM-38: Income tracking endpoint**
`GET /api/trips/income` — returns total earnings, trip count, grouped by date. Small addition to tripController.js.

**Priority 2 — SCRUM-27/30/31: Ride request flow**
This is a design decision. Do you want a proper request/accept/reject flow (adds complexity), or is "driver starts trip directly" acceptable for this version? This affects Flutter design significantly.

**Priority 3 — SCRUM-53: Basic stats endpoint**
`GET /api/admin/stats` — total drivers, verified count, total trips, total revenue. One aggregation query.

Tell me which ones to build and I'll do them before Flutter.You've used 55% of your weekly rate limit. Your weekly rate limit will reset on May 4 at 5:30 AM. [Learn More](https://aka.ms/github-copilot-rate-limit-error)