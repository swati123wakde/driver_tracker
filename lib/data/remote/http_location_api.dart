import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/location_record.dart';
import 'location_api.dart';

/// Real HTTP client for the REST contract. Use it with the bundled mock
/// server (`dart run tool/mock_server.dart`) or any compatible backend:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// ```
class HttpLocationApi implements LocationApi {
  HttpLocationApi(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<List<String>> uploadBatch(List<LocationRecord> records) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/locations/batch'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'records': records.map((r) => r.toJson()).toList(),
          }),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['accepted'] as List<dynamic>).cast<String>();
  }
}
