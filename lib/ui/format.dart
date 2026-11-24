String _two(int v) => v.toString().padLeft(2, '0');

String formatTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

String formatCoord(double lat, double lng) =>
    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

String formatSpeed(double metresPerSecond) =>
    '${(metresPerSecond * 3.6).toStringAsFixed(0)} km/h';
