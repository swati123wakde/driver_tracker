// Minimal mock REST backend (no dependencies, dart:io only).
//
//   dart run tool/mock_server.dart
//   PORT=8080 FAILURE_RATE=0.3 dart run tool/mock_server.dart
//
// POST /v1/locations/batch  {"records":[{id, sessionId, lat, lng, ...}]}
//   -> 200 {"accepted":[ids]}   idempotent on `id`
//   -> 503 when a simulated outage is rolled
// GET  /v1/locations          -> {"count", "duplicatesIgnored", "records"}
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final failureRate =
      double.tryParse(Platform.environment['FAILURE_RATE'] ?? '') ?? 0.0;
  final random = Random();
  final records = <String, Map<String, dynamic>>{};
  var duplicatesIgnored = 0;

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('Mock location API on http://0.0.0.0:$port '
      '(failure rate ${(failureRate * 100).round()}%)');

  await for (final request in server) {
    final path = request.uri.path;
    try {
      if (request.method == 'POST' && path == '/v1/locations/batch') {
        if (random.nextDouble() < failureRate) {
          _json(request, 503, {'error': 'simulated outage'});
          continue;
        }
        final body = jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>;
        final batch = (body['records'] as List).cast<Map<String, dynamic>>();
        final accepted = <String>[];
        for (final r in batch) {
          final id = r['id'] as String;
          if (records.containsKey(id)) {
            duplicatesIgnored++;
          } else {
            records[id] = r;
          }
          accepted.add(id);
        }
        stdout.writeln('POST batch=${batch.length} total=${records.length} '
            'dupesIgnored=$duplicatesIgnored');
        _json(request, 200, {'accepted': accepted});
      } else if (request.method == 'GET' && path == '/v1/locations') {
        _json(request, 200, {
          'count': records.length,
          'duplicatesIgnored': duplicatesIgnored,
          'records': records.values.toList(),
        });
      } else {
        _json(request, 404, {'error': 'not found'});
      }
    } catch (e) {
      _json(request, 400, {'error': '$e'});
    }
  }
}

void _json(HttpRequest request, int status, Object body) {
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body))
    ..close();
}
