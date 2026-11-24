import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Online/offline signal for the sync engine.
///
/// `setSimulatedOffline` is a demo affordance: it lets a reviewer force the
/// app offline without toggling airplane mode.
abstract class ConnectivityService {
  /// Emits only when the effective online state changes.
  Stream<bool> get onlineChanges;
  Future<bool> get isOnline;

  bool get simulatedOffline;
  void setSimulatedOffline(bool value);
}

class AppConnectivityService implements ConnectivityService {
  AppConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _deviceOnline = true;
  bool _simulatedOffline = false;
  bool? _lastEmitted;

  Future<void> init() async {
    _deviceOnline = _hasNetwork(await _connectivity.checkConnectivity());
    _lastEmitted = _effective;
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _deviceOnline = _hasNetwork(results);
      _emitIfChanged();
    });
  }

  // A network interface is not a guarantee of internet access. That's fine:
  // a failed upload simply goes through the retry path.
  bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  bool get _effective => _deviceOnline && !_simulatedOffline;

  void _emitIfChanged() {
    final now = _effective;
    if (now != _lastEmitted) {
      _lastEmitted = now;
      _controller.add(now);
    }
  }

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  @override
  Future<bool> get isOnline async => _effective;

  @override
  bool get simulatedOffline => _simulatedOffline;

  @override
  void setSimulatedOffline(bool value) {
    _simulatedOffline = value;
    _emitIfChanged();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}
