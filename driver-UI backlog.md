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
