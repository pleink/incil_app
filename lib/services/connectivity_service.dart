import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
}
