What the full procedure would require
Step 1 — Add SQLite to the Flutter app
Install sqflite package. Define local table schemas that mirror your MongoDB models: trips, receipts, drivers. This is a separate database living on the phone.

Step 2 — Replace all API calls with a local-first pattern
Instead of:

It becomes:

Every write goes to SQLite first. The API is no longer called during the action.

Step 3 — Build a sync engine
This is the hardest part. You need a background service that:

Watches for internet connectivity
When online, finds all records where syncedToCloud = false
POSTs them to the backend
Marks them syncedToCloud = true on success
Handles conflicts — what if the same driver updated their rate both offline and online? Which wins?
Step 4 — Handle the reverse sync (server → device)
If the admin approves a driver while the driver is offline, the driver's app won't know. You need to pull updates from the server when connectivity returns.

Step 5 — Change every screen
Every screen that currently calls an API must now read from SQLite instead. The API is only used for sync. This means rewriting every data layer in Flutter.

Step 6 — Test every offline scenario

Trip created offline, synced later ✓
Rate changed offline, conflicts with server version ✗
Driver approved while offline ✗
Receipt generated offline, duplicate on sync ✗
The realistic assessment
What you have	What offline needs
1 database (MongoDB)	2 databases (SQLite + MongoDB)
Direct API calls	Local-first writes + background sync
Simple request/response	Conflict resolution logic
~5 API endpoints	5 API endpoints + 5 SQLite equivalents + sync engine
It roughly doubles the codebase complexity and introduces an entire class of bugs (sync conflicts, duplicate records, stale data) that are very hard to test.