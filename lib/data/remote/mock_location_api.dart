import 'dart:math';

import '../models/location_record.dart';
import 'location_api.dart';

/// In-app mock of the REST backend. No setup required, and it exposes
/// knobs so failure handling can be demonstrated from the UI.
///
/// When a request "fails", half the time the server never stored anything
/// (HTTP 503) and half the time it stored the batch but the response was
/// lost (HTTP 504). The second case is what makes idempotency necessary:
/// the client will resend, and the server must not create duplicates.
class MockLocationApi implements LocationApi {
  MockLocationApi({
    this.latency = const Duration(milliseconds: 400),
    this.failureRate = 0,
    Random? random,
  }) : _random = random ?? Random();

  Duration latency;

  /// 0.0 – 1.0 probability that a request fails.
  double failureRate;

  final Random _random;
  final Map<String, LocationRecord> _server = {};
  int _duplicatesIgnored = 0;
  int _requests = 0;

  int get uniqueCount => _server.length;
  int get duplicatesIgnored => _duplicatesIgnored;
  int get requestCount => _requests;

  @override
  Future<List<String>> uploadBatch(List<LocationRecord> records) async {
    _requests++;
    if (latency > Duration.zero) await Future<void>.delayed(latency);

    final fails = _random.nextDouble() < failureRate;
    if (fails && _random.nextBool()) {
      throw const ApiException(503, 'Service unavailable (simulated)');
    }

    final accepted = <String>[];
    for (final r in records) {
      if (_server.containsKey(r.id)) {
        _duplicatesIgnored++;
      } else {
        _server[r.id] = r;
      }
      accepted.add(r.id);
    }

    if (fails) {
      throw const ApiException(504, 'Gateway timeout, response lost (simulated)');
    }
    return accepted;
  }
}
