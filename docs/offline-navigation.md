# Bundled Sri Lanka offline navigation

The Customer and Driver apps include the same compressed country-wide road graph
from each app's own `assets/offline/sri_lanka.nav.gz`. Flutter packages it into both
installations. Users do not download or import maps. Updating the dataset requires
a new app release; there is no runtime map-server dependency.

The bundled extract is dated **2026-10-08**, contains 3,558,379 road geometry nodes,
305,301 road ways, 6,087 named settlements and **32,826 landmarks**, and occupies
**53,448,818 bytes (51.0 MiB)** in each app. Graph decompression happens in memory, not as an extra
download or installation step.

## Use

Open **Offline Trips & Maps → Offline navigation**. Search a station, hospital, fuel station, town or other mapped landmark in
English or its mapped local name, or long-press the map to choose a precise pin.
Offline trips use **car routing automatically**, with no vehicle selector on either
phone. Tap the Stations, Fuel or Hospitals shortcuts to browse matching places;
results prefer nearby places when a location is available. Tap a landmark icon
for its name and **Navigate here**. GPS automatically supplies the origin; no
manual starting point is required. **Follow GPS** keeps
the map centred on your position. **All directions** displays the turn list.

Customers can choose a destination before handing their offer QR to the driver.
The driver confirmation QR confirms the destination and trip start time. Both meters'
navigation buttons then open that destination. Offers made by older installations
without a destination continue to work. A destination selected inside the
navigation screen guides that phone; it does not change an accepted offer or fare.

Roads, settlement names, landmarks, coastlines, water areas, parks, railways and
selected public/named building outlines are drawn from bundled OSM geometry.
Zoom and My location controls make the map easier to explore. Landmark labels
are spaced by zoom to reduce clutter. Landmarks are collected from OSM nodes
and ways; some relation-only features and unmapped places remain unavailable.
Routes use an on-device A* search with incoming-edge states for turn restrictions.
The country graph stays in a persistent isolate, so decompression, spatial queries
and route calculation do not execute on Flutter's UI isolate. Bidirectional and
one-way road segments retain OSM node IDs; crossing bridges do not create invented
junctions. Route endpoints snap to an accessible road within 300 m. The map shows
the selected destination pin and reports a significant offset from the routed road.

Accurate foreground GPS fixes update remaining distance and the next instruction.
Two fixes more than 50 m off the route trigger recalculation, with a 10-second
cooldown. Navigation uses GPS without mobile data. Metering continues beneath the
navigation screen; navigation distance is never substituted for billed GPS distance.
Going into the background still has the existing foreground-meter limitations.

## Offline trip experience

Both offline hubs show map, location and account/driver-QR readiness. An ongoing
trip appears first as **Resume active trip**, and a saved passenger offer can be
continued before starting another trip. Three QR steps explain whose phone scans
next. The meter shows a large fare, distance, agreed rate and GPS status; passenger
readings are labelled estimates. History distinguishes locally saved trips,
waiting-to-sync driver receipts and synced trips. Pull to refresh local history;
the customer's sync icon refreshes cloud history when connected. Expired customer
identity proofs no longer appear as a prepared account.

## Coverage and limits

This is visual road navigation, with roundabout entry/exit and turn instructions.
It does not include voice guidance, lane guidance, live traffic, street-address
geocoding, satellite imagery or guaranteed road-condition information. Offline
search covers mapped settlements and landmarks; use a pin for a specific building or address.
Time estimates use conservative road-class speeds, capped by numeric maxspeed tags.

Public motor roads are included; private, destination-only, delivery-only,
non-motor and conditional-access roads are excluded. Car access is always used,
including when an older saved trip contains a legacy vehicle profile. Old QR
metadata is retained only for compatibility with saved handshakes. Mapped one-way and motor-vehicle
access restrictions, barriers and via-node no/only turn restrictions are respected.
Via-way and conditional turn restrictions are conservatively blocked instead of
evaluating time-dependent rules. This can exclude an otherwise usable route.
Missing or incorrect OSM tags remain a limitation: verify road signs and local
conditions. The map is a local OSM geometry map; it is not a downloaded raster tile map.

The expanded graph and search arrays consume additional RAM as well as increasing
both apps' installation size. Asset size, source timestamp and checksums are
recorded in `assets/manifest.json`; validate GPS and performance on target phones
before release. No online-trip screen or online navigation service uses this graph.

## Rebuild the data

From the repository root on Windows:

```powershell
python -m venv .tools/offline-nav
& .tools/offline-nav/Scripts/python.exe -m pip install -r scripts/navigation-requirements.txt
& .tools/offline-nav/Scripts/python.exe scripts/build_offline_navigation.py --download
```

The builder downloads the developer-side Geofabrik Sri Lanka `.osm.pbf` source
to ignored `.map-build/`, then generates the application asset and manifest.
An existing source is reused. To refresh it, remove that specific cached source
before rerunning, or supply `--source path/to/new-extract.osm.pbf`. Commit the
generated `.nav.gz`, manifest and notice with the code. The build does not run
automatically during app installation or a trip.

Run `flutter pub get` in both app folders after dependency changes.
Run `flutter test test/offline` from each app folder and analyze both apps. The tests
include actual Colombo, Kandy and Jaffna route calculations from the bundled file.
For device verification, disable Wi-Fi and mobile data before opening the map for
the first time, perform the QR handshake, follow a route, take a different turn,
confirm rerouting, finish the trip and exchange the receipt. Repeat with permission denial, expired account preparation, restart and
background/resume.

## Data and attribution

Source: [Geofabrik Sri Lanka](https://download.geofabrik.de/asia/sri-lanka.html).
Map/database: © OpenStreetMap contributors, distributed under
[ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
Attribution is displayed on each map; tap it to read the source and license links.
The adapted database, notice, exact source
hash and transformation source are included in this repository. See
[OpenStreetMap copyright](https://www.openstreetmap.org/copyright) and
`frontend_Driver/assets/offline/NOTICE.txt`.

Offline code lives in each app’s `lib/offline` folder, with map assets in `assets/offline`. There is no separate offline package to run. Apply future offline fixes to both copies. The default map builder updates both apps’ assets.
