import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _onlineController =
      StreamController<bool>.broadcast();

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;
  Stream<bool> get onlineStream => _onlineController.stream;

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final online = results.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
    if (_isOnline != online) {
      _isOnline = online;
      _onlineController.add(online);
      if (kDebugMode) {
        debugPrint('[Connectivity] online=$online results=$results');
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _onlineController.close();
  }
}
