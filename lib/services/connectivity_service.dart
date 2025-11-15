import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;
  static final _controller = StreamController<bool>.broadcast();
  static bool _isOnline = true;

  /// Stream of connectivity status (true = online, false = offline)
  static Stream<bool> get connectivityStream => _controller.stream;

  /// Current connectivity status
  static bool get isOnline => _isOnline;

  /// Initialize connectivity monitoring
  static Future<void> initialize() async {
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      
      if (wasOnline != _isOnline) {
        _controller.add(_isOnline);
      }
    });
  }

  /// Dispose resources
  static void dispose() {
    _subscription?.cancel();
    _controller.close();
  }

  /// Show offline banner
  static Widget buildOfflineBanner(BuildContext context) {
    return StreamBuilder<bool>(
      stream: connectivityStream,
      initialData: _isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (isOnline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.red,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'No internet connection',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}
