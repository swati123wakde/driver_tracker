import 'package:driver_tracker/bloc/tracking/tracking_bloc.dart';
import 'package:driver_tracker/data/local/in_memory_location_store.dart';
import 'package:driver_tracker/data/models/location_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fakes.dart';

void main() {
  late FakeLocationSource source;
  late InMemoryLocationStore store;
  late TrackingBloc bloc;

  LocationFix fix(int i) => LocationFix(
        latitude: 12.97 + i * 0.001,
        longitude: 77.59,
        timestamp: DateTime(2026, 1, 1, 9, 0, i),
      );

  setUp(() {
    source = FakeLocationSource();
    store = InMemoryLocationStore();
    bloc = TrackingBloc(source: source, store: store);
  });

  tearDown(() => bloc.close());

  test('every fix is persisted locally while tracking', () async {
    bloc.add(const TrackingStartRequested());
    await settle();
    expect(bloc.state.status, TrackingStatus.tracking);

    source
      ..push(fix(1))
      ..push(fix(2));
    await settle();

    final saved = await store.recent();
    expect(saved, hasLength(2));
    expect(saved.every((r) => !r.isSynced), isTrue);
    expect(bloc.state.pointsThisSession, 2);
    expect(bloc.state.lastFix, fix(2));
  });

  test('stopping cancels the location stream', () async {
    bloc.add(const TrackingStartRequested());
    await settle();
    bloc.add(const TrackingStopRequested());
    await settle();

    expect(bloc.state.status, TrackingStatus.idle);
    expect(source.hasListener, isFalse);
  });

  test('a location error stops tracking and surfaces the message', () async {
    bloc.add(const TrackingStartRequested());
    await settle();
    source.fail(Exception('permission denied'));
    await settle();

    expect(bloc.state.status, TrackingStatus.error);
    expect(bloc.state.errorMessage, contains('permission denied'));
  });
}
