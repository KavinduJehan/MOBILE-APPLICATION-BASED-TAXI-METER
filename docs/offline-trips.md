# Offline trips

The offline hub shows active trips and completed trips waiting to sync. Once a
completed trip has a cloud `serverId`, it leaves **Saved trips** and remains in
regular trip history. Its local journal is retained. Customers can use the sync
refresh button to check whether their driver has uploaded a trip.

This is a separate trip flow. Existing online booking, navigation, trip start/end,
pricing, socket and Google Maps screens keep their existing behavior.

## Prepare each phone while online

Driver: open **Offline Trips & Maps** on the dashboard. Refresh the driver profile
and **My QR Code** once while online so the profile ID, QR token and QR image are
saved for offline use. Existing installs with an older cached profile need this
refresh once.

Customer: open **My Trips → Offline Trips & Maps**. Tap **Prepare for offline**
while online. This saves a limited customer identity proof (valid for trip starts
within 30 days) so the driver can later sync the trip into the customer's account.
It is not an authentication token. Without it the trip still works locally, but
the backend stores it without a linked customer account.

Both apps include a Sri Lanka OpenStreetMap road graph in the installation.
There is no map download or import button. Open **Offline navigation** to search
for a town/village or long-press a destination, use automatic car
routing, and calculate a route from the current GPS position. Road maps, route
calculation, visual turn directions and GPS rerouting work without internet.
See [offline-navigation.md](offline-navigation.md) for data provenance, rebuilding
and navigation limits.

## Start and finish a trip without internet

1. Customer opens the offline section and scans the driver's **My QR Code**.
   This scan uses the embedded profile without waiting for the server.
2. Customer enters the agreed rate and generates an offline offer QR. Optionally
   select a destination on the bundled map before showing the offer to the driver.
   The destination is included in the acceptance handshake. Car navigation is
   automatic; the customer does not choose a vehicle profile.
3. Driver scans that offer in the offline section. The driver app checks the
   target QR token, offer ID, positive rate and 30-minute offer window, rejects
   repeated offers, and prevents a second active offline trip.
4. Driver accepts and shows a confirmation QR. Customer scans it to confirm
   the trip, passenger, agreed rate, destination and driver's start time before
   opening the offline meter. The driver can reopen the QR from their meter.
   The passenger offer is saved before showing its QR and can be resumed after an
   app restart. Refreshing the offer keeps its ID. Discard only an offer the
   driver has not accepted; discarding cannot remotely cancel a driver's trip.
5. Keep the meter or its **Offline navigation** screen open while travelling.
   The navigation screen can be opened on both phones and automatically reroutes
   after two accurate fixes more than 50 m from the route (with a 10-second
   cooldown). Both phones record GPS distance
   locally. The passenger's reading is an estimate; the driver's meter determines
   the final fare. Inaccurate or mocked fixes, stationary jitter and impossible
   jumps are excluded.
6. Driver ends the offline trip and shows the final receipt QR. Customer scans
   it to copy the driver's final distance, fare, end time and receipt number.
7. Local trips can be reopened from the offline section after navigating away
   or restarting the app. The driver can reopen a completed trip to show its
   receipt again or retry queueing it for sync.

## GPS and persistence limits

Tracking currently runs in the foreground while the meter screen is open. Going
into the background, closing the screen or restarting tracking clears the GPS
anchor and shows a tracking-gap notice. The app does not bill a straight line
across a gap. Accurate full-trip distance therefore requires keeping the meter or
its navigation screen open. Background metering would require a platform
foreground service and associated permissions.

The GPS odometer and route checkpoints are saved after each accepted fix.
Both apps contain the same distance filtering code in their own `lib/offline` folder. Local trip
journals and the driver's new offline sync queue are scoped to the account ID.
Older unowned SQLite rows are not automatically uploaded under a newly signed-in
driver account. The existing legacy `/trips/sync` endpoint remains available;
the new offline section uses `/trips/offline-sync`.

## Backend

Deploy the backend changes before testing account preparation or cloud sync:

- `GET /api/trips/offline-identity`: authenticated customer identity proof.
- `POST /api/trips/offline-sync`: authenticated driver upload of completed
  version-1 offline snapshots. The backend validates identity, distance, rate,
  total and times, and preserves the agreed rate regardless of the current online
  pricing mode.
- A unique `{driver, offlineLocalId}` index makes retrying the same completed trip
  idempotent. Receipt creation can recover after a previous partial write.

Driver sync attempts run at startup/login, connectivity changes, app resume,
completion, and every 30 seconds while the app is active. Upload failure never
prevents local completion. Customer can tap **Refresh synced offline trips**
after the driver uploads. Identity proofs are checked against trip start time,
so a later upload does not invalidate a proof that was valid when the ride began.

The offer and receipt QR codes are a physical handoff protocol, not signed
driver identity certificates. Customer account linking relies on the separate
server-issued limited identity proof. Full offline verification of a driver's
identity would require a signed driver credential and key distribution.

## Verification

From each app folder: `flutter test test/offline` covers GPS filtering and checkpoints,
QR mismatch rejection, account-scoped storage, legacy raster MBTiles/TMS loading,
one-way/access/turn-restriction routing, route progress and actual bundled-country
routes. The road graph parser and routing core make no network requests.
From `backend`: `node --test unit-tests/offlineTrip.node.test.js` covers offline
fare validation, customer identity proofs, role checks, idempotent retries and
recovery after a simulated receipt-write failure. These Node unit tests do not
connect to or clear a database.

Two-device check: install both apps and prepare profiles; disable Wi-Fi/mobile data; perform
all QR scans; travel with both screens open; finish and scan the receipt; restart
the apps and reopen both trips; reconnect the driver; confirm one cloud trip and
receipt; refresh the customer offline history. Repeat with GPS permission denied,
a wrong-driver offer, the same offer scanned twice, and an interrupted GPS stream.

References: [Geofabrik Sri Lanka](https://download.geofabrik.de/asia/sri-lanka.html),
[OpenStreetMap attribution and licensing](https://www.openstreetmap.org/copyright),
[MBTiles specification](https://github.com/mapbox/mbtiles-spec/blob/master/1.3/spec.md).

Offline code lives in each app’s `lib/offline` folder, with map assets in `assets/offline`. There is no separate offline package to run. Apply future offline fixes to both copies. The default map builder updates both apps’ assets.
