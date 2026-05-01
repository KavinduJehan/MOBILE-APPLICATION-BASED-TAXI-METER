Clear. Before building, let me confirm the exact flow so nothing is wrong:

---

**Full flow as I understand it:**

```
1. Customer opens app → GPS gets their location
2. Customer sets destination → app calls backend for nearby verified drivers
3. Backend returns drivers with: name, vehicle, ratePerKm, location, area
4. App shows drivers on map — red if above area average, green if at/below
5. Customer taps a driver → app shows estimated fare (distance × driver's rate)
6. Customer either:
   A. Sends request at driver's rate (standard)
   B. Types a lower suggested rate → sends negotiation request
7. Driver sees incoming request (customer name, pickup, drop, proposed rate)
8. Driver accepts or rejects
9. If accepted → trip automatically starts
10. If rejected → customer sees rejection, can pick another driver
```

---

**What this requires on the backend:**

| New piece | What it does |
|---|---|
| `Driver.location` field | Stores driver's current lat/lng |
| `PATCH /api/drivers/location` | Driver updates their GPS position |
| `RideRequest` model | Stores the request with negotiated rate, status |
| `POST /api/ride-requests` | Customer creates request (no auth needed) |
| `GET /api/ride-requests/incoming` | Driver polls for pending requests |
| `PATCH /api/ride-requests/:id/respond` | Driver accepts/rejects |
| `GET /api/ride-requests/:id` | Customer polls for status update |
| Auto-create trip on accept | When driver accepts, trip is created |

---

Two questions before I build:

1. **Does the customer need a name/phone on the request** — or fully anonymous like trips currently are?
2. **Distance calculation** — does the app calculate distance on the Flutter side (using GPS coordinates) and send it to the backend, or do you want the backend to calculate it from coordinates? The simplest approach is Flutter calculates and sends `estimatedDistanceKm` to the backend.You've used 55% of your weekly rate limit. Your weekly rate limit will reset on May 4 at 5:30 AM. [Learn More](https://aka.ms/github-copilot-rate-limit-error)