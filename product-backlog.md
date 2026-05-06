# Product Backlog
**Project:** Smart Taxi Meter  
**Date:** 2026-05-06  
**Status key:** ✅ Done | 🔴 High | 🟡 Medium | 🟢 Low

---

## ✅ Completed

| ID | Item |
|----|------|
| BE-01 | Driver model, auth (email+password), JWT |
| BE-02 | Driver QR generation and lookup |
| BE-03 | Ride request create, poll status, driver respond |
| BE-04 | Trip create, end, income summary |
| BE-05 | Area rate management (CRUD) |
| BE-06 | Admin: list drivers, verify/reject, all trips, stats endpoint |
| BE-07 | Customer model: register, request-OTP, verify-OTP (console log) |
| BE-08 | POST /ride-requests now requires customer JWT (customerName from token) |
| FL-01 | CustomerModel, AuthProvider (OTP flow), ApiService (customer endpoints) |
| FL-02 | AuthScreen — phone-only entry |
| FL-03 | PhoneVerificationScreen — 6-digit OTP, auto-send, resend, wired to backend |
| FL-04 | CustomerSignupScreen — first-time name entry, creates account then OTPs |
| FL-05 | Home screen shows real customer name from JWT |
| FL-06 | Profile screen shows real name + phone, sign-out clears token |
| FL-07 | QR scan (camera) → real driver data via GET /drivers/qr/:token |
| FL-08 | Driver verification screen — verified badge, real fields |
| FL-09 | Negotiate screen — rate validation, returns offer to caller |
| FL-10 | Ride request screen — Haversine distance, city dropdowns, sends JWT-auth POST |
| FL-11 | Waiting screen — 3s polling, accept/reject handling |
| FL-12 | Trip progress screen — confirm dialog before ending |
| FL-13 | Trip summary + Receipt screen — all real values, local receipt number |
| AD-01 | Admin login — email+password, regulator role check |
| AD-02 | Drivers page — list, filter, approve/reject |
| AD-03 | Trips page — full table from GET /admin/trips |

---

## 🔴 High Priority

| ID | Item | Detail |
|----|------|--------|
| FL-14 | **Wire Rate Comparison screen** | `rate_comparison.dart` still shows hardcoded Rs.150/130. Call `GET /api/rates?area=` and display real driver rate vs area average. |
| FL-15 | **My Trips screen** | Home "My Trips" card has empty `onTap`. Needs a new screen calling `GET /api/trips/my` (works with customer JWT). Returns list of trips for this customer. |
| AD-04 | **Admin Stats Dashboard** | `GET /api/admin/stats` exists and returns `{totalDrivers, verifiedCount, totalTrips, totalRevenue}`. No React page renders it yet. |
| BE-09 | **Customer JWT on status poll** | `GET /ride-requests/:id/status` is currently unauthenticated. Should validate the requester is the customer who created it. |

---

## 🟡 Medium Priority

| ID | Item | Detail |
|----|------|--------|
| FL-16 | **Nearby Drivers screen** | Home "Search Nearby Drivers" has empty `onTap`. Call `GET /api/drivers/nearby?area=` and show a list with name, vehicle, rate. |
| FL-17 | **Token persistence across restarts** | Token is in-memory only (`_inMemoryToken`). Use `flutter_secure_storage` so customers don't re-OTP every app launch. JWT is 30-day so this is important UX. |
| BE-10 | **Backend test suite — customer routes** | `tests/` directory has driver/trip/admin tests. No tests for `POST /customers/register`, `request-otp`, `verify-otp`. |
| BE-11 | **Rate limiting on OTP endpoint** | `POST /customers/request-otp` has no rate limit. A bad actor could hammer it. Add express-rate-limit (already a common dep pattern in this project). |
| AD-05 | **Admin rate management page** | No React UI for `GET/PATCH /api/rates`. Admin can't view or update area rates from the web interface. |

---

## 🟢 Low Priority / Deployment

| ID | Item | Detail |
|----|------|--------|
| FL-18 | **SMS provider integration** | OTP currently `console.log` only. Integrate Twilio or Dialog Axiata (Sri Lanka) for real SMS delivery before production. |
| FL-19 | **My Trips for customer** | `GET /api/trips/my` currently filters by driver JWT. Needs a separate customer trip history endpoint or query by customerId. |
| DP-01 | **Verify .env not committed** | Check `.gitignore` covers `backend/.env`. `JWT_SECRET` and DB URI must not be in the repo. |
| DP-02 | **MongoDB Atlas migration** | Swap local MongoDB URI for Atlas cluster URI in `backend/.env` before production. |
| DP-03 | **Flutter base URL for production** | `api_service.dart` hardcodes `http://10.0.2.2:5000/api` (emulator). Update to deployed server URL before release build. |
| DP-04 | **Admin UI production URL** | `admin-ui/.env` has `REACT_APP_API_URL=http://localhost:5000/api`. Update before `npm run build`. |
| DP-05 | **Flutter APK release build** | Run `flutter build apk --release` and test on a physical device. |
| DP-06 | **Admin UI production build** | Run `npm run build` in `admin-ui/` and deploy static files (Netlify / Vercel / nginx). |
| DP-07 | **Backend deployment** | Deploy Node.js backend to Railway / Render / EC2. Set environment variables in the host dashboard. |

---

## Immediate Next Steps (suggested order)

1. **FL-14** — Rate Comparison (small, high value for demo)
2. **FL-15** — My Trips screen (needed for end-to-end story)
3. **AD-04** — Admin Stats Dashboard (completes admin UI)
4. **FL-17** — Token persistence (improves demo UX)
5. **BE-10** — Customer route tests (needed before submission)

---

---

# Driver App — UI Backlog
**Who:** Driver (separate Flutter app, separate developer)  
**Backend base URL:** `http://<server-ip>:5000/api`  
**Auth:** Email + Password → JWT (role: `"driver"`)  
**Note:** All endpoints already exist and are tested on the backend. The driver app just needs to call them.

---

## Backend API Reference (Driver App)

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/api/auth/register` | ❌ | Driver signup |
| POST | `/api/auth/login` | ❌ | Email + password login → JWT |
| GET | `/api/drivers/profile` | ✅ | Get own profile (name, area, rate, verified status, qrCode) |
| POST | `/api/drivers/generate-qr` | ✅ | Generate/refresh QR code → returns base64 image + token |
| PATCH | `/api/drivers/location` | ✅ | Update live location `{ lat, lng }` |
| PATCH | `/api/rates/my-rate` | ✅ | Set per-km rate `{ ratePerKm }` |
| GET | `/api/rates/area?area=Colombo` | ❌ | Get average rate for an area |
| GET | `/api/ride-requests/incoming` | ✅ | Poll for pending ride requests sent to this driver |
| PATCH | `/api/ride-requests/:id/respond` | ✅ | Accept/reject `{ action: "accept"\|"reject", agreedRatePerKm? }` |
| POST | `/api/trips` | ✅ | Create trip after accepting request |
| PATCH | `/api/trips/:id/end` | ✅ | End active trip → auto-generates receipt |
| GET | `/api/trips/my` | ✅ | List all this driver's trips |
| GET | `/api/trips/income` | ✅ | Earnings summary `{ totalEarnings, totalTrips, byDay[] }` |

---

## Screen-by-Screen Backlog

### DR-01 — Splash Screen
- Show app logo for 2s
- Check if token exists in storage → if yes, skip to Home; if no, go to Login

### DR-02 — Login Screen
- Email + password fields
- Call `POST /api/auth/login`
- On success: store JWT securely (`flutter_secure_storage`), navigate to Home
- On fail: show error from `{ message }` response body
- Link to "Register" screen

### DR-03 — Registration Screen
- Fields: Full Name, Phone, Email, Password, License Number, Vehicle Number, Area (dropdown)
- Call `POST /api/auth/register`
- On success: navigate to Login with a "Account created — pending admin verification" message
- Validation: all fields required, password min 8 chars

### DR-04 — Home / Dashboard Screen
- Greeting: "Hello, [name]!"
- **Verification status banner:** if `isVerified = false`, show a yellow warning "Your account is pending admin approval. You cannot receive ride requests yet."
- Menu cards:
  - 📋 Incoming Requests → DR-07
  - 🗺️ My QR Code → DR-05
  - 📊 Trip History → DR-09
  - 💰 Earnings → DR-10
  - ⚙️ Settings → DR-11

### DR-05 — My QR Code Screen
- Call `GET /api/drivers/profile` on load
- Display the `qrCode` field as a QR image (base64 → `Image.memory`)
- Show driver name, vehicle number, area, rate below the QR
- "Refresh QR" button → calls `POST /api/drivers/generate-qr` → updates displayed QR
- Instruction text: "Show this QR to your customer so they can scan and verify you"

### DR-06 — Edit Profile / Rate Screen
- Pre-fill fields from `GET /api/drivers/profile`
- Editable: Rate per km (numeric field)
- "Save Rate" → `PATCH /api/rates/my-rate` with `{ ratePerKm }`
- Show current area average beside the field (call `GET /api/rates/area?area=<driver area>`)
- Non-editable: name, license, vehicle (admin managed)

### DR-07 — Incoming Requests Screen
- Poll `GET /api/ride-requests/incoming` every 3 seconds
- Show a list of pending requests — each card shows:
  - Customer name
  - Pickup → Destination
  - Estimated distance (km)
  - Customer's suggested rate (if different from your rate, show in orange)
  - Your rate vs suggested side-by-side
- Tap a request card → DR-08

### DR-08 — Request Detail & Respond Screen
- Show full request details:
  - Customer name
  - Pickup address, Destination address
  - Estimated distance
  - Driver's own rate: Rs. X/km
  - Customer suggested rate (if any): Rs. Y/km (highlighted)
  - Estimated fare at both rates
- Two buttons:
  - ✅ **Accept** — calls `PATCH /api/ride-requests/:id/respond` with `{ action: "accept" }`
    - If customer suggested a rate and driver wants to agree: include `agreedRatePerKm`
    - On success → navigate to DR-09-Active (active trip screen)
  - ❌ **Reject** — calls `PATCH /api/ride-requests/:id/respond` with `{ action: "reject" }`
    - On success → pop back to DR-07

### DR-08a — Active Trip Screen (after accepting)
- Show trip info:
  - Customer name
  - Pickup → Destination
  - Distance, Rate, Estimated fare
- "End Trip" button → confirmation dialog → calls `PATCH /api/trips/:id/end`
  - Response includes `{ trip, receipt }` — navigate to Trip Summary DR-08b

### DR-08b — Trip Summary Screen (after ending)
- Show completed trip details: customer, distance, rate, total fare
- Show receipt number from response
- "Back to Home" button → navigate to Home, clear active trip state

### DR-09 — Trip History Screen
- Call `GET /api/trips/my` on load
- List each trip:
  - Customer name, date, route (start → end), distance, fare, status badge
- Empty state: "No trips yet"

### DR-10 — Earnings Screen
- Call `GET /api/trips/income` on load
- Show summary cards:
  - Total Earnings (Rs. X)
  - Total Completed Trips
- Bar chart or simple list of earnings by day (`byDay[]` array from API)
- Empty state: "No completed trips yet"

### DR-11 — Settings Screen
- Driver profile info (read-only): name, phone, email, license, vehicle, area
- "Update Rate" shortcut → DR-06
- "Show My QR" shortcut → DR-05
- "Sign Out" → clears stored JWT → navigate to Login

---

## Technical Requirements for Driver App

| Item | Detail |
|------|--------|
| **Base URL** | `http://10.0.2.2:5000/api` for emulator, real IP for physical device |
| **Auth header** | `Authorization: Bearer <jwt>` on every protected request |
| **Token storage** | `flutter_secure_storage` — persist across restarts (30-day JWT) |
| **Polling** | DR-07 polls every 3s using `Timer.periodic`. Cancel timer on dispose. |
| **State management** | `provider` package (same pattern as customer app) |
| **Error handling** | Backend always returns `{ message: "..." }` — show it in a SnackBar or inline text |
| **QR display** | Profile returns `qrCode` as base64 string. Use `Image.memory(base64Decode(qrCode))` |

---

## Suggested Build Order for Driver App

| Sprint | Screens | Reason |
|--------|---------|--------|
| 1 | DR-02, DR-03, DR-04 | Auth + home — nothing works without login |
| 2 | DR-05, DR-06 | QR display — needed for customer app to scan |
| 3 | DR-07, DR-08 | Ride request flow — core feature |
| 4 | DR-08a, DR-08b | Active trip + end trip — completes the ride loop |
| 5 | DR-09, DR-10 | History + earnings — secondary screens |
| 6 | DR-01, DR-11 | Splash + settings — polish |

