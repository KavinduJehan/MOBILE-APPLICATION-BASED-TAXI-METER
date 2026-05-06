# Project Objective
**Smart Taxi Meter — Regulated Fare Platform (Sri Lanka)**

---

## Problem Being Solved

Ride-hailing platforms like PickMe and Uber charge drivers a commission on every fare.
Drivers lose a percentage of every trip to the platform indefinitely.

This system eliminates that. Drivers pay a **one-time registration fee** to join.
From that point on, every rupee of the fare goes directly to the driver — no middleman cut per trip.
The registration fees sustain the platform operationally.

---

## Stakeholders

| Role | Who | How they interact |
|------|-----|-------------------|
| **Customer** | Passenger | Flutter mobile app |
| **Driver** | Tuk-tuk / taxi driver | Flutter mobile app (separate) |
| **Regulator / Admin** | Transport authority | React web dashboard (PC) |

---

## Business Model

- Driver pays a **one-time registration fee** to get on the platform
- Admin (regulator) **manually verifies** each driver before they go live
- Once verified, driver earns **100% of the fare** — no per-ride commission
- Platform revenue = registration fees only
- Admin publishes **area average rates** so the market stays transparent

---

## Two Operating Modes

### Mode 1 — Offline (Street Hail)

> Customer is on the street and physically sees a driver.

1. Customer opens app, taps **Scan Driver QR**
2. Customer scans the QR code displayed on the driver's vehicle / phone
3. App fetches driver's live data from backend — shows:
   - Name, license number, vehicle number
   - Verified badge (admin-approved) or warning if unverified
   - Driver's per-km rate
   - Area average rate for comparison
4. Customer can **negotiate** a lower per-km rate or proceed at the driver's rate
5. Customer fills in pickup and destination → sends **Ride Request**
6. Driver receives request on their app → **Accepts** (or rejects)
7. On acceptance: driver status → **Occupied** (disappears from online search)
8. Trip runs — fare calculated from GPS distance × agreed rate
9. Driver ends trip → receipt auto-generated for both sides

### Mode 2 — Online (In-App Search)

> Customer opens the app without a driver in mind.

1. Customer taps **Search Nearby Drivers**
2. App calls `GET /api/drivers/nearby?area=` → shows list of **available** (not occupied) verified drivers
3. Customer selects a driver from the list
4. Same flow from step 3 onwards as Mode 1 (rate shown, negotiate, request, accept, trip, receipt)

---

## Rate System

- Each driver sets their own **per-km rate** via their app
- Backend maintains **area average rates** (admin-managed)
- Both rates are shown to the customer before requesting a ride:
  - "Driver's rate: Rs. X / km"
  - "Area average: Rs. Y / km"
- Customer can submit a **counter-offer** (must be lower than driver's rate, greater than 0)
- Driver sees the counter-offer and chooses to accept or reject
- If accepted, `agreedRatePerKm` is stored on the ride request and used for fare calculation
- If rejected or no negotiation, driver's original rate applies

---

## Driver Status Lifecycle

```
Registered → [Admin approves] → Available
                                    │
                          Customer sends Ride Request
                                    │
                          Driver accepts request
                                    ↓
                                 Occupied  ←──── disappears from nearby search
                                    │
                          Trip ends (driver taps "End Trip")
                                    ↓
                                 Available  ←──── reappears in nearby search
```

**Occupied state** is set when: `PATCH /api/ride-requests/:id/respond` with `action: "accept"`  
**Available state** is restored when: `PATCH /api/trips/:id/end`

> ⚠️ **Backend gap:** Driver `status` field (available/occupied) not yet added to the Driver model.
> `GET /drivers/nearby` needs to filter out occupied drivers.
> This must be implemented before the online search mode works correctly.

---

## Fare Calculation

```
Fare = Distance (km) × Agreed Rate (Rs/km)
```

- **Current implementation:** Haversine formula (straight-line) × 1.25 road factor
- **Planned improvement:** Google Directions API for real road distance (post-MVP sprint)
- Distance and fare are shown as an **estimate** to the customer before the ride
- Final fare is locked when the driver ends the trip

---

## What Each App Does

### Customer App (Flutter)
- Phone OTP login (no email, no Firebase — backend OTP logged to console in dev)
- Scan driver QR (offline mode)
- Search nearby available drivers (online mode)
- View driver verification status and rate
- Negotiate rate
- Send ride request with pickup + destination
- Poll for driver accept/reject
- View active trip progress
- Receive receipt after trip ends
- View trip history

### Driver App (Flutter — separate)
- Email + password login
- Registration with license and vehicle details
- Generate and display QR code
- Set per-km rate
- View incoming ride requests
- Accept or reject (with optional agreed rate)
- View active trip, end trip
- View trip history and earnings summary

### Admin UI (React Web)
- Regulator login
- Review and approve/reject driver registrations
- View all trips across the platform
- Manage area average rates
- View platform stats (total drivers, trips, revenue)

---

## What Is Out of Scope (Current Phase)

- Real SMS delivery (OTP is console.log in dev — Twilio integration is a later sprint)
- Live GPS map (Google Maps replaces city dropdowns after both apps are complete)
- Payment gateway (cash payment assumed — digital payments are a future feature)
- Driver-to-customer in-app messaging
- Ratings and reviews

---

## Key Technical Decisions

| Decision | Reason |
|----------|--------|
| No Firebase | Removed complexity — backend OTP is fully controlled, no 3rd-party dependency |
| No per-ride commission tracking | Business model is registration-fee only, backend doesn't need to calculate platform cut |
| JWT 30-day expiry | Drivers and customers don't re-authenticate frequently — fits mobile UX |
| Separate Flutter apps for customer and driver | Different UX needs, different team members, cleaner separation of concerns |
| Admin web only (no mobile) | Regulators work at desks — no need for mobile admin app |
| City dropdowns (MVP) | Pragmatic for demo — replaced by Google Maps in next sprint |
