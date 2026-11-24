import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/sync/sync_bloc.dart';
import 'bloc/tracking/tracking_bloc.dart';
import 'core/theme.dart';
import 'data/local/location_store.dart';
import 'data/remote/mock_location_api.dart';
import 'services/connectivity_service.dart';
import 'services/location_source.dart';
import 'services/sync_service.dart';
import 'ui/home_page.dart';

/// Root widget. All dependencies are injected so tests can pass fakes.
class DriverTrackerApp extends StatelessWidget {
  const DriverTrackerApp({
    super.key,
    required this.store,
    required this.locationSource,
    required this.connectivity,
    required this.syncService,
    this.mockApi,
  });

  final LocationStore store;
  final LocationSource locationSource;
  final ConnectivityService connectivity;
  final SyncService syncService;
  final MockLocationApi? mockApi;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TrackingBloc(source: locationSource, store: store),
        ),
        BlocProvider(
          create: (_) => SyncBloc(
            syncService: syncService,
            store: store,
            connectivity: connectivity,
            mockApi: mockApi,
          )..add(const SyncSubscriptionRequested()),
        ),
      ],
      child: MaterialApp(
        title: 'Driver Tracker',
        debugShowCheckedModeBanner: false,
        theme: buildDarkAmberTheme(),
        darkTheme: buildDarkAmberTheme(),
        themeMode: ThemeMode.dark,
        home: const HomePage(),
      ),
    );
  }
}
