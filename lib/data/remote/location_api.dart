import '../models/location_record.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}

/// Backend contract: `POST /v1/locations/batch`.
///
/// The server must be idempotent on `record.id`: it stores a record once and
/// acknowledges it again (without storing) when it is re-sent.
abstract class LocationApi {
  /// Uploads [records] and returns the ids the server acknowledged.
  /// Throws on transport or server errors.
  Future<List<String>> uploadBatch(List<LocationRecord> records);
}
