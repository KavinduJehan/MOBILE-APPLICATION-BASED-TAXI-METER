Based on everything I've read across the full codebase, here's the complete execution plan:

---

## Execution Plan

### Phase 1 — Dev Environment (Day 1)
Get all three components running locally at the same time.

| # | Task | Command |
|---|---|---|
| 1.1 | Start backend | `cd backend && npm run dev` |
| 1.2 | Start admin UI | `cd admin-ui && npm start` |
| 1.3 | Seed dev data | `node scripts/seedAdmin.js && node scripts/seedDemo.js` |
| 1.4 | Fix git push error | Resolve the exit code 1 on `git push origin main` (likely needs `git pull --rebase` first) |

---

### Phase 2 — Flutter: Foundation (Days 2–3)
Wire up the Flutter app so it can talk to the backend.

**2.1 Add dependencies to pubspec.yaml:**
```yaml
dio: ^5.x                    # HTTP client
flutter_secure_storage: ^9.x # store JWT
provider: ^6.x               # share auth state
firebase_core: ^3.x          # Firebase base
firebase_auth: ^5.x          # phone OTP
```

**2.2 Create an API service layer** (`lib/services/api_service.dart`)
- Base URL constant (`http://10.0.2.2:5000/api` for Android emulator)
- Attach `Authorization: Bearer <token>` header on every authenticated request
- Centralised error handling matching the backend's `{ message }` shape

**2.3 Create an `AuthProvider`** (`lib/providers/auth_provider.dart`)
- Holds the JWT token and `Driver` object in memory
- Persists token to `flutter_secure_storage`
- Exposes `login()`, `registerWithEmail()`, `loginWithPhone()`, `logout()`

**2.4 Initialise Firebase** in main.dart
- Add `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
- Call `Firebase.initializeApp()` before `runApp()`

---

### Phase 3 — Flutter: Auth Screens (Days 3–4)

| Screen | Change needed |
|---|---|
| `PhoneVerificationScreen` | Replace hardcoded bypass → real Firebase OTP → `POST /api/auth/phone-login` |
| `EmailVerificationScreen` | Replace hardcoded bypass → `POST /api/auth/login` using email + password |
| `AuthScreen` | Pass credentials down to verification screens properly |
| `OnboardingScreen` | Wire to `POST /api/auth/register` (name, licenseNumber, vehicleNumber, area) |

---

### Phase 4 — Flutter: Core Driver Screens (Days 4–6)

| Screen | API call to wire |
|---|---|
| `Profile` | `GET /api/drivers/profile` — replace hardcoded name/email |
| `Home` | Show real driver name from `AuthProvider` |
| `Profile` → rate edit | `PATCH /api/rates` |
| `Profile` → generate QR | `POST /api/drivers/generate-qr` → display returned base64 QR image |
| `Profile` → location | `PATCH /api/drivers/location` — call on app resume/foreground |

---

### Phase 5 — Flutter: Ride Request Flow (Days 6–8)

| Screen | API call to wire |
|---|---|
| `QRScan` | Real camera scan → decode JSON → extract `token` → `GET /api/drivers/qr/:qrToken` |
| `DriverVerificationScreen` | Display real driver data from QR lookup response |
| `RideRequestScreen` | `POST /api/ride-requests` with real pickup/dest coords + estimated distance (Haversine × 1.25) |
| `NegotiateScreen` | Set `suggestedRatePerKm` in the ride request body |
| Poll for response | Customer polls `GET /api/ride-requests/:id/status` every ~3s |
| Driver incoming | Driver polls `GET /api/ride-requests/incoming` |
| Driver respond | `PATCH /api/ride-requests/:id/respond` with `{ accept: true/false }` |

---

### Phase 6 — Flutter: Trip Screens (Days 8–9)

| Screen | API call to wire |
|---|---|
| `TripProgressScreen` | Replace hardcoded km/fare → data from trip object; poll `GET /api/trips/my` |
| End trip | `PATCH /api/trips/:id/end` → returns `{ trip, receipt }` |
| `TripSummaryScreen` | Display real fare from `endTrip` response |
| `ReceiptScreen` | Display real receipt fields (receiptNumber, driver name, distance, rate, totalFare) |

---

### Phase 7 — Admin UI (Days 9–10)
The admin UI is already connected. These are the remaining gaps:

- [ ] **Stats dashboard** — `GET /api/admin/stats` response fields are all there, just needs a dashboard page
- [ ] **Trips list** — `GET /api/admin/trips` exists but no Trips page renders it yet (the `Trips.jsx` page may be incomplete — verify)
- [ ] **Rate comparison view** — `GET /api/rates?area=` response can feed a chart

---

### Phase 8 — Testing & Hardening (Days 10–11)
- Run the full backend test suite: `npm test` — all passing ✅
- Manual end-to-end smoke test: register driver → scan QR → request ride → negotiate → accept → start trip → end trip → view receipt
- Admin login → verify driver → view stats
- Check `.env` is in .gitignore and never committed

---

### Phase 9 — Deployment Prep (Day 12)
- Replace `MONGO_URI` in `.env` with Atlas cloud URI (template already in `.env.example`)
- Replace `http://localhost:5000` with deployed server URL in both Flutter (`api_service.dart`) and admin-ui (`.env`)
- Build Flutter APK: `flutter build apk --release`
- Build admin UI: `npm run build`

---

### Dependency Map
```
Phase 1 → unblocks everything
Phase 2 → must complete before Phases 3–6
Phase 3 → must complete before Phases 4–6
Phases 4, 5, 6 → can be parallelised across team members
Phase 7 → independent, can run in parallel with Phases 3–6
Phase 8 → requires Phases 3–7 complete
Phase 9 → requires Phase 8 complete
```