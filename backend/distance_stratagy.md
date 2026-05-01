Haversine on Device
Why this works perfectly for your case:

GPS satellite signal works completely without internet — the phone always knows its coordinates
Haversine formula = straight-line distance from two GPS coordinates, runs on device, zero network needed
For Sri Lanka's road geometry (mostly non-highway, winding roads), add a road factor of 1.25 — multiply Haversine result by 1.25 to approximate actual road distance
Result is calculated on Flutter, sent to backend as estimatedDistanceKm
Backend never needs to call any external API

Haversine(pickup, destination) × 1.25 = estimatedDistanceKm
This is how many budget taxi apps in South/Southeast Asia work. Accurate enough for fare calculation and works in zero signal.

