import 'dart:async';

import 'package:driver_tracker/data/models/location_record.dart';
import 'package:driver_tracker/data/remote/location_api.dart';
import 'package:driver_tracker/services/connectivity_service.dart';
import 'package:driver_tracker/services/location_source.dart';

/// Lets pending async work (microtasks, zero-length timers) finish.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class FakeConnectivity implements ConnectivityService {
  FakeConnectivity({bool online = false}) : _online = online;

  bool _online;
  final _controller = StreamController<bool>.broadcast();

  void setOnline(bool value) {
    _online = value;
    _controller.add(value);
  }

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  @override
  Future<bool> get isOnline async => _online;

  @override
  bool get simulatedOffline => false;

  @override
  void setSimulatedOffline(bool value) => setOnline(!value);
}

enum ApiBehavior {
  /// Store and acknowledge.
  ok,

  /// Fail before storing (e.g. 503).
  fail,

  /// Store, then lose the response (e.g. timeout after commit).
  lostAck,
}

/// Idempotent fake backend with a scripted sequence of behaviours.
class FakeLocationApi implements LocationApi {
  final Map<String, LocationRecord> server = {};
  final List<ApiBehavior> script = [];
  final List<List<String>> requests = [];
  int duplicatesIgnored = 0;

  /// When set, uploads wait for it — lets tests overlap sync calls.
  Completer<void>? gate;

  @override
  Future<List<String>> uploadBatch(List<LocationRecord> records) async {
    requests.add(records.map((r) => r.id).toList());
    final g = gate;
    if (g != null) await g.future;

    final behavior = script.isEmpty ? ApiBehavior.ok : script.removeAt(0);
    if (behavior == ApiBehavior.fail) {
      throw const ApiException(503, 'Service unavailable');
    }
    for (final r in records) {
      if (server.containsKey(r.id)) {
        duplicatesIgnored++;
      } else {
        server[r.id] = r;
      }
    }
    if (behavior == ApiBehavior.lostAck) {
      throw const ApiException(504, 'Gateway timeout');
    }
    return records.map((r) => r.id).toList();
  }

  /// How many times each record id was sent in total.
  Map<String, int> get sendCounts {
    final counts = <String, int>{};
    for (final ids in requests) {
      for (final id in ids) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }
}

class FakeLocationSource implements LocationSource {
  final _controller = StreamController<LocationFix>.broadcast();

  bool get hasListener => _controller.hasListener;
  void push(LocationFix fix) => _controller.add(fix);
  void fail(Object error) => _controller.addError(error);

  @override
  String get label => 'Fake GPS';

  @override
  Stream<LocationFix> watch() => _controller.stream;
}

LocationRecord record(String id, DateTime at) => LocationRecord(
      id: id,
      sessionId: 'session-1',
      latitude: 12.97,
      longitude: 77.59,
      accuracy: 5,
      speed: 10,
      recordedAt: at,
    );
