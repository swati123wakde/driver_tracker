import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../data/models/location_record.dart';

class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Anything that produces GPS fixes. Lets the app swap real GPS for a
/// simulator (and tests for a fake) without touching the BLoC.
abstract class LocationSource {
  String get label;

  /// A stream of fixes. Listening starts tracking; cancelling stops it.
  Stream<LocationFix> watch();
}

/// Simulates a vehicle driving around central Bengaluru.
class SimulatedLocationSource implements LocationSource {
  SimulatedLocationSource({
    this.interval = const Duration(seconds: 2),
    this.startLatitude = 12.9716,
    this.startLongitude = 77.5946,
    Random? random,
  }) : _random = random ?? Random();

  final Duration interval;
  final double startLatitude;
  final double startLongitude;
  final Random _random;

  @override
  String get label => 'Simulated GPS';

  @override
  Stream<LocationFix> watch() {
    var lat = startLatitude;
    var lng = startLongitude;
    var heading = _random.nextDouble() * 2 * pi;
    const metresPerDegree = 111320.0;

    return Stream<LocationFix>.periodic(interval, (_) {
      heading += (_random.nextDouble() - 0.5) * 0.6; // gentle turns
      final speed = 8 + _random.nextDouble() * 6; // 8–14 m/s (~30–50 km/h)
      final distance = speed * interval.inMilliseconds / 1000;
      lat += distance * cos(heading) / metresPerDegree;
      lng += distance * sin(heading) / (metresPerDegree * cos(lat * pi / 180));
      return LocationFix(
        latitude: lat,
        longitude: lng,
        accuracy: 4 + _random.nextDouble() * 6,
        speed: speed,
        timestamp: DateTime.now(),
      );
    });
  }
}

/// Real device GPS via the geolocator plugin (foreground only in this demo;
/// see docs/BACKGROUND_TRACKING.md for the background setup).
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource({this.distanceFilterMetres = 10});

  final int distanceFilterMetres;

  @override
  String get label => 'Device GPS';

  @override
  Stream<LocationFix> watch() async* {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailableException('Location services are off.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationUnavailableException('Location permission denied.');
    }

    yield* Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMetres,
      ),
    ).map(
      (p) => LocationFix(
        latitude: p.latitude,
        longitude: p.longitude,
        accuracy: p.accuracy,
        speed: p.speed,
        timestamp: p.timestamp,
      ),
    );
  }
}
