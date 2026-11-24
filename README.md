# Driver Tracker: location tracking with offline sync

A small Flutter app built for the *Driver Location Tracking & Offline
Synchronization* assessment. It uses **BLoC** state management and a
**dark theme with amber accents**.

| Requirement | Where |
|---|---|
| Start / stop tracking (simulated or real GPS) | `TrackingBloc`, `services/location_source.dart` |
| Store records locally when offline | `data/local/sqflite_location_store.dart` (every fix is stored locally first) |
| Auto-sync when connectivity returns | `services/sync_service.dart` (`start()` listens to connectivity) |
| No duplicate submissions, retries on failure | `SyncService` (single flight, idempotency keys, exponential backoff) |
| Maintainable architecture + state management | layered `data / services / bloc / ui`, `flutter_bloc` |
| Automated tests | `test/sync_service_test.dart`, `test/tracking_bloc_test.dart`, `test/widget_test.dart` |
| Background tracking write-up | [`docs/BACKGROUND_TRACKING.md`](docs/BACKGROUND_TRACKING.md) |

## Setup

Requires Flutter **3.27+** (Dart 3.5+).

```bash
git clone <repo-url> driver_tracker && cd driver_tracker

# Generate the android/ and ios/ runners (existing lib/ and test/ files are kept)
flutter create . --platforms=android,ios --project-name driver_tracker

flutter pub get
flutter analyze
flutter test
flutter run
```

### Platform permissions (only needed for real GPS)

The default run uses **simulated GPS** and needs no permissions. To use the
device GPS (`--dart-define=USE_REAL_GPS=true`), add the following.

`android/app/src/main/AndroidManifest.xml` (inside `<manifest>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

`ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Your location is recorded during an active trip.</string>
```

### Run modes

```bash
# 1. Default: simulated GPS + in-app mock backend (zero setup)
flutter run

# 2. Real device GPS
flutter run --dart-define=USE_REAL_GPS=true

# 3. Real HTTP calls against the bundled mock REST server
dart run tool/mock_server.dart                     # terminal 1 (FAILURE_RATE=0.3 to inject 503s)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080   # Android emulator → host
curl http://localhost:8080/v1/locations            # inspect what the server stored
```

> Plain `http://` on Android needs `android:usesCleartextTraffic="true"` on
> `<application>` in debug builds. The iOS Simulator can use
> `http://localhost:8080`.

## Demo walkthrough

1. Tap **Start tracking**. A point is recorded every 2 seconds, and the
   **Pending** count rises, then drops as points sync.
2. Turn on **Simulate offline**. Points keep recording and **Pending** grows,
   because nothing is sent.
3. Turn it off. The backlog uploads in batches automatically.
4. Drag **Mock API failure rate** to 50%. Failed points show
   `retry #n at hh:mm:ss` and are retried with exponential backoff.
   **Sync now** forces an immediate retry.
5. Watch "*N duplicate re-sends ignored*". When the mock server stores a
   batch but "loses" the response, the client resends it. The server keeps
   one copy, so its unique count always equals the number of points recorded.

## Architecture

```
lib/
├── data/
│   ├── models/location_record.dart     LocationFix (raw GPS) + LocationRecord (persisted, sync metadata)
│   ├── local/                          LocationStore interface · SQLite impl · in-memory impl (tests)
│   └── remote/                         LocationApi interface · in-app mock · HTTP client
├── services/
│   ├── location_source.dart            Simulated / Geolocator sources behind one interface
│   ├── connectivity_service.dart       connectivity_plus + "simulate offline" override
│   ├── retry_policy.dart               exponential backoff with cap + jitter
│   └── sync_service.dart               the sync engine (pure Dart, no Flutter)
├── bloc/
│   ├── tracking/                       TrackingBloc: session lifecycle, fix → local store
│   └── sync/                           SyncBloc: queue stats, connectivity, user actions
├── ui/                                 HomePage + cards (BlocBuilder / BlocSelector)
├── core/theme.dart                     dark + amber Material 3 theme
├── app.dart                            dependency injection via BlocProviders
└── main.dart                           composition root, build-time flags
tool/mock_server.dart                   dependency-free REST mock (dart:io)
```

```
GPS ──► TrackingBloc ──► LocationStore (SQLite) ──► SyncService ──► LocationApi
                               │   inserted ↑            ▲   ▲
                               │            └─ debounce ─┘   └── connectivity regained / retry timer / Sync now
                               └──► SyncBloc ──► UI (counts, recent points)
```

## Technical decisions

- **Offline-first, always.** `TrackingBloc` never calls the network. It writes
  every fix to SQLite and returns. Online and offline take the same code
  path, so the offline case is never a special branch that might go
  untested. Points also survive app restarts; leftovers are drained when
  `SyncService.start()` runs.
- **Sync logic in a service, not in a BLoC.** `SyncService` is plain Dart with
  injected store, API, connectivity and clock. That makes it deterministic to
  test, and reusable from a background isolate where no widgets or BLoCs
  exist (see the background doc). `SyncBloc` only presents its state.
- **Duplicate prevention works at three levels.**
  1. *Locally:* the record id is the SQLite primary key, inserted with
     `ConflictAlgorithm.ignore`.
  2. *In the client:* sync is single-flight. Concurrent triggers
     (reconnect + new point + Sync now) share the running future and queue
     one follow-up run, so a record is never in two in-flight requests.
  3. *End to end:* each record carries a client-generated UUID that the
     server treats as an idempotency key. A record is marked synced only
     after it is acknowledged, giving at-least-once delivery. If the
     response is lost, the resend is ignored by the server, so it is stored
     exactly once.
- **Retries.**
  - Each failed record gets `attempts + 1` and a `nextAttemptAt` based on an
    exponential backoff (2 s, 4 s, 8 s … capped at 5 min, ±20% jitter).
  - `pendingDue()` only returns records whose time has come, and a single
    timer is armed for the earliest one.
  - Retries pause while offline, because reconnecting triggers a sync anyway.
  - After a failed batch the run stops, rather than hammering a failing
    server.
  - Records are never dropped: losing a driver's trail is worse than
    retrying.
- **Batching.** Uploads go in batches of 25, oldest first. New points are
  debounced (1 s) so live tracking doesn't produce one request per fix.
- **Connectivity.** `connectivity_plus` reports network interfaces, not
  reachability. A false "online" is harmless because the upload fails and
  goes through the retry path.
- **Interfaces at the edges** (`LocationSource`, `LocationStore`,
  `LocationApi`, `ConnectivityService`). These let the demo switch between
  simulated and real implementations with `--dart-define`, and let tests use
  fakes without a mocking library.

## Tests

```bash
flutter test
```

- `sync_service_test.dart`
  - offline records stay pending and nothing is sent
  - auto-upload on reconnect
  - batching
  - **overlapping sync calls upload each record once**
  - **lost acknowledgement → retry without server duplicates**
  - backoff timing and growth
  - manual sync bypasses backoff
  - `RetryPolicy` caps
- `tracking_bloc_test.dart`: fixes are persisted while tracking; stop cancels
  the stream; location errors are surfaced.
- `widget_test.dart`: home screen smoke test.

The sync tests use an injected clock and a scripted fake API (`ok` / `fail` /
`lostAck`), so they are deterministic and finish in milliseconds.

## Known limitations / next steps

- Foreground tracking only; the background design is in
  `docs/BACKGROUND_TRACKING.md`.
- No authentication, and no purging of old synced rows. A real app would
  prune synced rows after N days.
- Permanent 4xx rejections (e.g. a validation error) are retried like
  transient errors. A production version would move them to a dead-letter
  state.
#   d r i v e r _ t r a c k e r  
 