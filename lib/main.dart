import 'package:flutter/material.dart';

import 'app.dart';
import 'data/local/sqflite_location_store.dart';
import 'data/remote/http_location_api.dart';
import 'data/remote/location_api.dart';
import 'data/remote/mock_location_api.dart';
import 'services/connectivity_service.dart';
import 'services/location_source.dart';
import 'services/sync_service.dart';

/// Build-time switches:
///   --dart-define=USE_REAL_GPS=true            use device GPS instead of the simulator
///   --dart-define=API_BASE_URL=http://host:8080 use the HTTP mock server instead of the in-app mock
const _useRealGps = bool.fromEnvironment('USE_REAL_GPS');
const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await SqfliteLocationStore.open();

  final connectivity = AppConnectivityService();
  await connectivity.init();

  final mockApi = _apiBaseUrl.isEmpty ? MockLocationApi() : null;
  final LocationApi api = mockApi ?? HttpLocationApi(_apiBaseUrl);

  final syncService = SyncService(
    store: store,
    api: api,
    connectivity: connectivity,
  )..start();

  final LocationSource source = _useRealGps
      ? const GeolocatorLocationSource()
      : SimulatedLocationSource();

  runApp(DriverTrackerApp(
    store: store,
    locationSource: source,
    connectivity: connectivity,
    syncService: syncService,
    mockApi: mockApi,
  ));
}
