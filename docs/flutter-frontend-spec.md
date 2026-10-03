# Flutter Frontend — API Integration Specification

**Backend base URL (development):** `http://localhost:5000/api`  
**Backend base URL (production):** `https://mobile-application-based-taxi-meter.onrender.com/api`  

All authenticated requests must include the header:
```
Authorization: Bearer <token>
```
The token is returned from login/register and must be stored securely (e.g. `flutter_secure_storage`).

---

## Table of Contents

1. [App Structure Overview](#1-app-structure-overview)
2. [Authentication — Driver](#2-authentication--driver)
3. [Driver Profile & QR Code](#3-driver-profile--qr-code)
4. [Rate Management](#4-rate-management)
5. [Location Updates](#5-location-updates)
6. [Nearby Drivers & Area Rates (Customer)](#6-nearby-drivers--area-rates-customer)
7. [QR Code Scanning (Customer)](#7-qr-code-scanning-customer)
8. [Ride Request Flow (Customer)](#8-ride-request-flow-customer)
9. [Ride Request Flow (Driver)](#9-ride-request-flow-driver)
10. [Trip Management (Driver)](#10-trip-management-driver)
11. [Trip History & Receipts (Driver)](#11-trip-history--receipts-driver)
12. [Distance Calculation](#12-distance-calculation)
13. [Map Marker Colour Logic](#13-map-marker-colour-logic)
14. [Error Handling Reference](#14-error-handling-reference)

---

## 1. App Structure Overview

There are **two user types** — the same Flutter app should handle both via role-based routing:

| User | How they log in | Role value |
|---|---|---|
| Driver | Register + Login | `"driver"` |
| Customer | No login, no registration | *(anonymous)* |

After login the `role` field in the response determines which screen set to load.

### Screen sets

**Driver screens**
- Register / Login
- Dashboard (profile, QR code display, current rate)
- Start trip (manual — for trips not initiated via ride request)
- Active trip (end trip button + live fare display)
- Trip history + receipt viewer
- Settings (update rate per km)

**Customer screens**
- Home (map with nearby verified drivers)
- Driver detail (after tapping marker or scanning QR)
- Fare estimate + ride request form
- Waiting screen (polling for driver response)
- Ride confirmed screen (shows agreed rate + trip details)

---

## 2. Authentication — Driver

### Register
```
POST /api/auth/register
```
**Body (JSON):**
```json
{
  "name": "Kamal Perera",
  "email": "kamal@example.com",
  "phone": "0771234567",
  "password": "securepassword",
  "licenseNumber": "LIC-001",
  "vehicleNumber": "CAB-1234",
  "area": "Colombo"
}
```
**Success `201`:**
```json
{
  "token": "<jwt>",
  "driver": {
    "id": "abc123",
    "name": "Kamal Perera",
    "email": "kamal@example.com",
    "role": "driver"
  }
}
```
> Store the token. New drivers are **unverified by default** (`isVerified: false`). They can log in and generate a QR code but customers will not see them on the map until a regulator approves them.

---

### Login
```
POST /api/auth/login
```
**Body:**
```json
{
  "email": "kamal@example.com",
  "password": "securepassword"
}
```
**Success `200`:** Same shape as register response.

---

## 3. Driver Profile & QR Code

### Get own profile
```
GET /api/drivers/profile
Authorization: Bearer <token>
```
**Success `200`:** Full driver document (no password field).
```json
{
  "_id": "abc123",
  "name": "Kamal Perera",
  "email": "kamal@example.com",
  "phone": "0771234567",
  "licenseNumber": "LIC-001",
  "vehicleNumber": "CAB-1234",
  "area": "Colombo",
  "ratePerKm": 85,
  "isVerified": true,
  "qrCode": "data:image/png;base64,iVBORw0KGgo...",
  "location": { "lat": 6.9271, "lng": 79.8612, "updatedAt": "2026-05-01T10:00:00Z" }
}
```

---

### Generate / refresh QR code
```
POST /api/drivers/generate-qr
Authorization: Bearer <token>
```
No body needed. Returns:
```json
{
  "qrCode": "data:image/png;base64,iVBORw0KGgo..."
}
```
Display this as an image widget. The QR encodes an opaque token — never the driver's MongoDB `_id`.

> **When to call this:** On first login if `qrCode` is null, or when the driver explicitly refreshes. Do not call on every app open — the QR token does not change unless the driver regenerates it.

---

## 4. Rate Management

### Update per-km rate
```
PATCH /api/rates/my-rate
Authorization: Bearer <token>
```
**Body:**
```json
{ "ratePerKm": 90 }
```
**Success `200`:** Updated driver document (no password).

---

## 5. Location Updates

The driver app should send GPS position to the backend periodically so customers can see live driver positions on the map.

```
PATCH /api/drivers/location
Authorization: Bearer <token>
```
**Body:**
```json
{ "lat": 6.9271, "lng": 79.8612 }
```
**Success `200`:** Updated driver document.

> **Recommended interval:** Every 10–15 seconds while the app is in the foreground. Use a `Timer.periodic` in Flutter. Pause updates when the app is backgrounded to save battery.

---

## 6. Nearby Drivers & Area Rates (Customer)

### Get verified drivers by area
```
GET /api/drivers/nearby?area=Colombo
```
No auth required.

**Success `200`:**
```json
[
  {
    "_id": "abc123",
    "name": "Kamal Perera",
    "vehicleNumber": "CAB-1234",
    "ratePerKm": 85,
    "area": "Colombo",
    "qrCode": "data:image/png;base64,..."
  }
]
```
> The `location` field is **not** returned here. Use the QR scan flow or the driver detail endpoint to get full info. Map pin positions should come from a separate location-broadcast mechanism if real-time tracking is needed (future enhancement). For now, place markers at a fixed point per area.

---

### Get area average rate
```
GET /api/rates/area?area=Colombo
```
No auth required.

**Success `200`:**
```json
{
  "area": "Colombo",
  "averageRate": 82.5,
  "drivers": [
    { "_id": "abc123", "name": "Kamal Perera", "ratePerKm": 85, "vehicleNumber": "CAB-1234" }
  ]
}
```
Use `averageRate` to colour map markers — see [Section 13](#13-map-marker-colour-logic).

---

## 7. QR Code Scanning (Customer)

When a customer scans a driver's QR code, the QR payload is a JSON string:
```json
{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "name": "Kamal Perera",
  "licenseNumber": "LIC-001",
  "vehicleNumber": "CAB-1234",
  "area": "Colombo",
  "ratePerKm": 85
}
```

Parse the JSON, extract `token`, then call:
```
GET /api/drivers/qr/:token
```
No auth required.

**Success `200`:** Full driver document (no password).

Use the returned data to show the driver detail screen and pre-fill the ride request form.

---

## 8. Ride Request Flow (Customer)

### Step 1 — Create a ride request
```
POST /api/ride-requests
```
No auth required.

**Body:**
```json
{
  "driverId": "abc123",
  "customerName": "Nimal Silva",
  "pickupLat": 6.9271,
  "pickupLng": 79.8612,
  "pickupAddress": "Colombo Fort",
  "destLat": 6.8735,
  "destLng": 79.8874,
  "destAddress": "Dehiwala",
  "estimatedDistanceKm": 8.5,
  "suggestedRatePerKm": 70
}
```

| Field | Required | Notes |
|---|---|---|
| `driverId` | ✅ | From driver detail screen |
| `pickupLat` / `pickupLng` | ✅ | Customer's current GPS position |
| `destLat` / `destLng` | ✅ | Destination selected on map |
| `estimatedDistanceKm` | ✅ | Calculated on device — see [Section 12](#12-distance-calculation) |
| `customerName` | ❌ | Optional — defaults to `"Anonymous"` |
| `pickupAddress` / `destAddress` | ❌ | Optional human-readable label |
| `suggestedRatePerKm` | ❌ | Omit for standard request. Only send if customer wants to negotiate a **lower** rate. Values ≥ driver's rate are silently ignored. |

**Success `201`:**
```json
{
  "_id": "req001",
  "status": "pending",
  "driverRatePerKm": 85,
  "suggestedRatePerKm": 70,
  "agreedRatePerKm": null,
  ...
}
```
**Save the `_id`** — you need it to poll for status.

---

### Step 2 — Poll for driver response
```
GET /api/ride-requests/:id/status
```
No auth required. Poll every 3–5 seconds.

**Response:**
```json
{
  "_id": "req001",
  "status": "pending",
  "agreedRatePerKm": null,
  "trip": null,
  "driver": {
    "name": "Kamal Perera",
    "vehicleNumber": "CAB-1234",
    "phone": "0771234567"
  }
}
```

| `status` value | What to show customer |
|---|---|
| `"pending"` | "Waiting for driver response…" spinner |
| `"accepted"` | Show confirmed screen — display `agreedRatePerKm` and `trip` details |
| `"rejected"` | "Driver declined. Please choose another driver." |
| `"expired"` | "Request timed out. Please try again." *(future feature)* |

On `"accepted"`, the `trip` object is populated with `{ status, startTime, totalFare }`.

---

## 9. Ride Request Flow (Driver)

### Poll for incoming requests
```
GET /api/ride-requests/incoming
Authorization: Bearer <token>
```
Poll every 5–10 seconds while driver is "available".

**Success `200`:** Array of pending requests.
```json
[
  {
    "_id": "req001",
    "customerName": "Nimal Silva",
    "pickupLat": 6.9271,
    "pickupLng": 79.8612,
    "pickupAddress": "Colombo Fort",
    "destLat": 6.8735,
    "destLng": 79.8874,
    "destAddress": "Dehiwala",
    "estimatedDistanceKm": 8.5,
    "driverRatePerKm": 85,
    "suggestedRatePerKm": 70,
    "status": "pending",
    "createdAt": "2026-05-01T10:00:00Z"
  }
]
```

Show each request as a card with:
- Customer name
- Pickup → destination
- Distance
- Driver's rate vs customer's suggested rate (if negotiation)
- Accept / Reject buttons

---

### Accept or reject a request
```
PATCH /api/ride-requests/:id/respond
Authorization: Bearer <token>
```
**Body:**
```json
{ "action": "accept" }
```
or
```json
{ "action": "reject" }
```

**On accept — `200`:**
```json
{
  "rideRequest": {
    "_id": "req001",
    "status": "accepted",
    "agreedRatePerKm": 70,
    ...
  },
  "trip": {
    "_id": "trip001",
    "status": "ongoing",
    "startTime": "2026-05-01T10:05:00Z",
    "totalFare": 595.00,
    ...
  }
}
```
Navigate to the **active trip screen** using the returned `trip._id`.

**On reject — `200`:** Returns the updated `rideRequest` with `status: "rejected"`.

---

## 10. Trip Management (Driver)

Trips can be created two ways:
1. **Automatically** — when driver accepts a ride request (preferred flow). Trip is already created.
2. **Manually** — driver starts trip directly (legacy flow, for trips not initiated via ride request).

### Manual trip creation
```
POST /api/trips
Authorization: Bearer <token>
```
**Body:**
```json
{
  "startLocation": "Colombo Fort",
  "endLocation": "Dehiwala",
  "distanceKm": 8.5,
  "ratePerKm": 85,
  "customerName": "Nimal Silva"
}
```
`distanceKm` and `ratePerKm` are required. `totalFare` is calculated by the backend (`distanceKm × ratePerKm`).

**Success `201`:** Trip document with `status: "ongoing"`.

---

### End a trip
```
PATCH /api/trips/:id/end
Authorization: Bearer <token>
```
No body needed.

**Success `200`:**
```json
{
  "trip": {
    "_id": "trip001",
    "status": "completed",
    "endTime": "2026-05-01T10:45:00Z",
    "totalFare": 722.50,
    ...
  },
  "receipt": {
    "_id": "rec001",
    "receiptNumber": "RCP-A1B2C3D4",
    "totalFare": 722.50,
    "issuedAt": "2026-05-01T10:45:00Z",
    ...
  }
}
```
Display the receipt after the trip ends.

---

## 11. Trip History & Receipts (Driver)

### Get own trip history
```
GET /api/trips/my
Authorization: Bearer <token>
```
**Success `200`:** Array of trips sorted newest first.
```json
[
  {
    "_id": "trip001",
    "customerName": "Nimal Silva",
    "startLocation": "Colombo Fort",
    "endLocation": "Dehiwala",
    "distanceKm": 8.5,
    "ratePerKm": 85,
    "totalFare": 722.50,
    "status": "completed",
    "startTime": "2026-05-01T10:05:00Z",
    "endTime": "2026-05-01T10:45:00Z"
  }
]
```
Receipts are embedded in the `endTrip` response. For history display, calculate summary statistics client-side (total earnings = sum of `totalFare` for completed trips).

---

## 12. Distance Calculation

**The backend does not calculate distance.** The Flutter app must calculate and send `estimatedDistanceKm`.

Use the **Haversine formula × 1.25 road factor**:

```dart
import 'dart:math';

double haversineDistance(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0; // Earth radius in km
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) *
      sin(dLng / 2) * sin(dLng / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c * 1.25; // 1.25 road factor
}

double _toRad(double deg) => deg * pi / 180;
```

Use `geolocator` for the customer's current position and a map tap / search for the destination.

---

## 13. Map Marker Colour Logic

When showing drivers on the map, colour their markers based on the **area average rate**:

```
GET /api/rates/area?area=<area>   →  { averageRate: 82.5 }
```

| Condition | Marker colour |
|---|---|
| `driver.ratePerKm <= averageRate` | 🟢 Green |
| `driver.ratePerKm > averageRate` | 🔴 Red |

Fetch area rates once when the map loads and cache locally for the session. Refresh if the user changes area.

Recommended packages:
- `flutter_map: ^6.1.0` + OpenStreetMap tiles (no API key needed)
- `latlong2: ^0.9.0`
- `geolocator: ^12.0.0`

---

## 14. Error Handling Reference

| HTTP status | Meaning | Suggested UI action |
|---|---|---|
| `400` | Bad request / missing fields | Show field-level validation error |
| `401` | Missing or invalid JWT | Clear stored token, redirect to login |
| `403` | Driver not verified / wrong role | Show "Account pending verification" message |
| `404` | Resource not found | Show "Not found" message |
| `409` | Conflict (e.g. email exists, request already responded to) | Show specific conflict message from `message` field |
| `500` | Server error | Show generic "Something went wrong, try again" |

All error responses have the shape:
```json
{ "message": "Human-readable error description" }
```

---

## Packages Recommended

```yaml
dependencies:
  http: ^1.2.0                  # or dio: ^5.4.0 for interceptors
  flutter_secure_storage: ^9.0.0
  geolocator: ^12.0.0
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  mobile_scanner: ^5.0.0        # QR scanning
  provider: ^6.0.0              # or riverpod for state management
```
