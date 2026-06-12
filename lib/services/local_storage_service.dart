import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';

class LocalStorageService {
  LocalStorageService(this._prefs);

  final SharedPreferences _prefs;

  static const _kCompletedOnboardingVersion = 'completedOnboardingVersion';
  static const _kCachedAppStateJson = 'cachedAppStateJson';

  int get completedOnboardingVersion =>
      _prefs.getInt(_kCompletedOnboardingVersion) ?? 0;

  Future<void> setCompletedOnboardingVersion(int version) async {
    await _prefs.setInt(_kCompletedOnboardingVersion, version);
  }

  AppState? readCachedAppState() {
    final raw = _prefs.getString(_kCachedAppStateJson);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return AppState.fromJson(decoded);
    } catch (e, st) {
      developer.log(
        'Failed to decode cached AppState; ignoring cache.',
        name: 'LocalStorageService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<void> writeCachedAppState(AppState state) async {
    await _prefs.setString(_kCachedAppStateJson, jsonEncode(state.toJson()));
  }
}
