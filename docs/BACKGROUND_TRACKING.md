# Continuous background GPS tracking (Android & iOS)

The demo tracks in the foreground only. This note explains how I would keep
tracking while the app is minimised or the phone is locked, and how that
fits the existing offline-first pipeline.

## What stays the same

The data path does not change. Each fix is written to SQLite first. The
`SyncService` uploads pending rows with backoff, and the server deduplicates
by record id. Background mode only changes **how long the Dart isolate stays
alive and keeps receiving location updates**. Because nothing is uploaded
straight from the GPS callback, losing the network or being throttled in the
background never loses points.

## Android

1. **Foreground service of type `location`.** This is the only reliable way
   to keep receiving GPS updates when the app is not visible. It requires a
   persistent notification ("Trip in progress"). With geolocator, you get one
   by passing `AndroidSettings(foregroundNotificationConfig: ...)` to
   `getPositionStream`. For more control, use a native service built on
   `FusedLocationProviderClient`, or `flutter_background_service`.
2. **Manifest permissions:**
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
   <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/> <!-- Android 14+ -->
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>          <!-- Android 13+ -->
   <uses-permission android:name="android.permission.WAKE_LOCK"/>
   ```
   Also declare `android:foregroundServiceType="location"` on the service.
3. **Permission flow.** Ask for foreground location first. On Android 11+,
   "Allow all the time" can only be granted from system settings, so explain
   why before sending the driver there. Google Play also requires a background
   location declaration and a prominent disclosure.
4. **Start the service while the app is visible.** That means starting it
   from the "Start trip" tap. Android 12+ blocks starting foreground services
   from the background.
5. **Battery and OEM killers.** Ask to be excluded from battery optimisation
   (`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, with a justified use case), and
   document vendor-specific auto-start settings (Xiaomi, Oppo, Vivo, etc.).
6. **Robustness.**
   - Re-arm tracking after reboot when a trip was active
     (`RECEIVE_BOOT_COMPLETED`).
   - Schedule a `WorkManager` job with a `NetworkType.CONNECTED` constraint
     (via the `workmanager` plugin). It flushes the queue even if the app
     process died before syncing.
7. **Battery tuning.**
   - Use a `distanceFilter` (e.g. 10–25 m) and a sensible interval.
   - Use high accuracy only while moving; drop to balanced power when the
     vehicle is stationary (detected via the Activity Recognition API).

## iOS

1. **Capabilities.** Enable Background Modes → *Location updates*
   (`UIBackgroundModes: location`). Optionally add *Background fetch* /
   `BGTaskScheduler` for deferred sync.
2. **Info.plist:**
   - `NSLocationWhenInUseUsageDescription`
   - `NSLocationAlwaysAndWhenInUseUsageDescription`
3. **CLLocationManager settings** (geolocator `AppleSettings`):
   - `allowBackgroundLocationUpdates: true`
   - `pauseLocationUpdatesAutomatically: false` during an active trip
   - `activityType: ActivityType.automotiveNavigation`
   - `showBackgroundLocationIndicator: true` (blue status-bar pill)
4. **Permissions.** Start with *When In Use*. That already allows continuous
   updates while a trip started in the foreground is running in the
   background. Request *Always* only if tracking must resume without the
   driver opening the app.
5. **Termination.**
   - If the user force-quits, iOS stops standard updates.
   - Use **Significant Location Change** monitoring or **region monitoring**
     (`CLMonitor`, iOS 17+) to have the system relaunch the app. Then restart
     precise updates and drain the queue.
   - Use a background `URLSession` to make uploads survive suspension.
6. **App Review.** State clearly why background location is needed (a
   driver's active delivery). Track only during an active trip.

## Flutter specifics

- With a foreground service (Android) or background location mode (iOS), the
  main isolate keeps running, so the existing BLoC + `SyncService` work
  unchanged.
- If the process is killed and relaunched headlessly, the work runs in a
  **background isolate**. That isolate has no widgets or BLoCs. Its entry
  point (`@pragma('vm:entry-point')`) builds the same `LocationStore` and
  `SyncService` directly. That reuse is why the sync logic lives in plain
  services rather than in a BLoC. SQLite handles access from both isolates;
  keep one writer per process.
- **Production option:** a maintained plugin such as
  `flutter_background_geolocation` (Transistor Software, licensed for Android
  release builds) bundles all of the above, plus motion detection and
  persistence. That trade-off is worth evaluating against maintaining native
  code.
