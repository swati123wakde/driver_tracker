import 'package:driver_tracker/app.dart';
import 'package:driver_tracker/data/local/in_memory_location_store.dart';
import 'package:driver_tracker/data/remote/mock_location_api.dart';
import 'package:driver_tracker/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('home screen renders tracking and sync sections', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = InMemoryLocationStore();
    final connectivity = FakeConnectivity(online: true);
    final mockApi = MockLocationApi(latency: Duration.zero);
    final sync = SyncService(
      store: store,
      api: mockApi,
      connectivity: connectivity,
      autoRetry: false,
    );

    await tester.pumpWidget(DriverTrackerApp(
      store: store,
      locationSource: FakeLocationSource(),
      connectivity: connectivity,
      syncService: sync,
      mockApi: mockApi,
    ));
    await tester.pump();

    expect(find.text('Driver Tracker'), findsOneWidget);
    expect(find.text('Start tracking'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Mock API failure rate'), findsOneWidget);
    expect(find.byKey(const Key('sync-now')), findsOneWidget);
  });
}
